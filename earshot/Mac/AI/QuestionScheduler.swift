//  QuestionScheduler.swift
//  Decides when the companion may speak up on the wrist, releases queued
//  questions at good moments, and turns the user's answers into help.

import Foundation

/// Pure policy (unit-tested).
enum QuestionPolicy {
    static func canRelease(now: Date, settings: AppSettings, releasedToday: Int, lastRelease: Date?,
                           wordsLastFiveMinutes: Int, calendarBusy: Bool) -> (allowed: Bool, reason: String) {
        if !settings.questionsEnabled {
            return (false, "Proactive questions are turned off in Settings.")
        }
        if settings.isQuietHour(now) {
            return (false, "Quiet hours (\(hourText(settings.quietHoursStart))–\(hourText(settings.quietHoursEnd))).")
        }
        let limit = max(0, settings.maxQuestionsPerDay)
        if releasedToday >= limit {
            if limit == 0 { return (false, "The daily question limit is set to 0.") }
            return (false, "Daily limit reached (\(releasedToday) of \(limit) questions today).")
        }
        if let lastRelease {
            let gap = TimeInterval(max(0, settings.minMinutesBetweenQuestions)) * 60
            let elapsed = now.timeIntervalSince(lastRelease)
            if elapsed < gap {
                let waitMinutes = max(1, Int(((gap - elapsed) / 60).rounded(.up)))
                let agoMinutes = Int(max(0, elapsed) / 60)
                return (false, "Last question was \(agoMinutes) min ago; the next one can come in about \(waitMinutes) min.")
            }
        }
        if settings.avoidQuestionsDuringConversation && wordsLastFiveMinutes > 60 {
            return (false, "You seem to be in a conversation (\(wordsLastFiveMinutes) words in the last 5 minutes).")
        }
        if settings.avoidQuestionsDuringMeetings && calendarBusy {
            return (false, "Your calendar shows you're in a meeting.")
        }
        return (true, "Clear to ask (\(releasedToday) of \(limit) questions so far today).")
    }

    private static func hourText(_ hour: Int) -> String {
        String(format: "%02ld:00", ((hour % 24) + 24) % 24)
    }
}

final class QuestionScheduler: @unchecked Sendable {
    private let db: Database
    private let llm: LLMService
    private let calendar: CalendarService

    private let lock = NSLock()
    private var storedOnApprovalAnswered: (@Sendable (_ approvalID: String, _ approved: Bool) -> Void)?
    private var storedOnNewActions: (@Sendable ([ProposedAction]) -> Void)?
    private var storedLastDecision = "Not checked yet."
    private var ticking = false
    private var resolvingVoice = false
    /// Prompt ids whose answer is being processed (guards against duplicate deliveries from the watch).
    private var inFlight: Set<String> = []

    private static let noSpeech = "(no speech captured)"
    private static let defaultVoiceWindow: TimeInterval = 25
    private static let voiceGrace: TimeInterval = 90
    private static let voiceHardLimit: TimeInterval = 20 * 60
    private static let snoozeInterval: TimeInterval = 2 * 3_600
    private static let followUpDelay: TimeInterval = 86_400
    private static let questionLifetime: TimeInterval = 36 * 3_600
    /// Unanswered questions released within this window block new ones (keeps the wrist calm).
    private static let outstandingWindow: TimeInterval = 6 * 3_600
    private static let maxOutstanding = 2

    private static let declineAnswers: Set<String> = ["not now", "no thanks", "skip", "no thank you", "nah", "dismiss"]
    private static let laterAnswers: Set<String> = ["later", "ask later", "ask me later", "ask again later"]
    private static let affirmativeAnswers: Set<String> = [
        "yes", "y", "yeah", "yep", "sure", "ok", "okay", "approve", "approved", "allow", "confirm",
        "do it", "go ahead", "go", "yes please",
    ]

    init(db: Database, llm: LLMService, calendar: CalendarService) {
        self.db = db
        self.llm = llm
        self.calendar = calendar
    }

    // MARK: Public state

    var onApprovalAnswered: (@Sendable (_ approvalID: String, _ approved: Bool) -> Void)? {
        get { locked { storedOnApprovalAnswered } }
        set { locked { storedOnApprovalAnswered = newValue } }
    }

    var onNewActions: (@Sendable ([ProposedAction]) -> Void)? {
        get { locked { storedOnNewActions } }
        set { locked { storedOnNewActions = newValue } }
    }

    var lastDecision: String { locked { storedLastDecision } }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func setDecision(_ text: String) {
        locked { storedLastDecision = text }
        Log.debug("QuestionScheduler: \(text)")
    }

    private func claim(_ promptID: String) -> Bool {
        locked { inFlight.insert(promptID).inserted }
    }

    private func unclaim(_ promptID: String) {
        locked { _ = inFlight.remove(promptID) }
    }

    // MARK: Tick

    func tick() async {
        let started: Bool = locked {
            if ticking { return false }
            ticking = true
            return true
        }
        guard started else { return }
        defer { locked { ticking = false } }

        let now = Date()
        let settings = SettingsStore.current
        expireStale(now: now)
        releaseDueNotices(now: now, settings: settings)

        let releasedToday = db.countPromptsReleased(kinds: [.question, .nudge], since: now.startOfDay)
        let lastRelease = db.lastPromptRelease(kinds: [.question, .nudge])
        let words = db.wordCount(from: now.addingTimeInterval(-300), to: now)
        let busy = calendar.isBusy(at: now)
        let decision = QuestionPolicy.canRelease(now: now, settings: settings, releasedToday: releasedToday,
                                                 lastRelease: lastRelease, wordsLastFiveMinutes: words,
                                                 calendarBusy: busy)
        if !decision.allowed {
            setDecision("Holding questions: \(decision.reason)")
        } else {
            let outstanding = db.prompts(statuses: [.pending, .delivered], limit: 100).filter { isOutstandingQuestion($0, now: now) }
            if outstanding.count >= QuestionScheduler.maxOutstanding {
                setDecision("Holding questions: \(outstanding.count) earlier questions are still unanswered on the watch.")
            } else if let next = pickNext(now: now) {
                release(next)
                setDecision("Asked “\(next.title.clipped(60))”. \(decision.reason)")
            } else {
                setDecision("Nothing worth asking right now. \(decision.reason)")
            }
        }

        // Make sure spoken answers are finalised even when no new audio arrives.
        await resolveVoiceAnswers()
    }

    private func isOutstandingQuestion(_ prompt: StoredPrompt, now: Date) -> Bool {
        guard prompt.kind == .question || prompt.kind == .nudge else { return false }
        if let expires = prompt.expiresAt, expires <= now { return false }
        guard let released = prompt.releasedAt else { return false }
        return now.timeIntervalSince(released) < QuestionScheduler.outstandingWindow
    }

    private func isExpired(_ prompt: StoredPrompt, now: Date) -> Bool {
        guard let expires = prompt.expiresAt else { return false }
        return expires < now
    }

    private func isDue(_ prompt: StoredPrompt, now: Date) -> Bool {
        guard let notBefore = prompt.notBefore else { return true }
        return notBefore <= now
    }

    private func expireStale(now: Date) {
        var changed = 0
        for var prompt in db.prompts(statuses: [.queued, .pending, .delivered], limit: 500) where isExpired(prompt, now: now) {
            prompt.status = .expired
            db.upsertPrompt(prompt)
            changed += 1
        }
        if changed > 0 {
            Log.info("QuestionScheduler: expired \(changed) stale prompt(s).")
            EarshotEvents.post(.prompts)
        }
    }

    /// Snoozed digests/answers/info come back on their own (they bypass the question budget),
    /// but not during quiet hours.
    private func releaseDueNotices(now: Date, settings: AppSettings) {
        guard !settings.isQuietHour(now) else { return }
        let noticeKinds: [PromptKind] = [.digest, .answer, .info]
        for prompt in db.prompts(statuses: [.queued], limit: 200) {
            guard noticeKinds.contains(prompt.kind), isDue(prompt, now: now), !isExpired(prompt, now: now) else { continue }
            release(prompt)
        }
    }

    /// Highest priority first, then oldest; skips (and expires) questions whose subject is resolved.
    private func pickNext(now: Date) -> StoredPrompt? {
        let candidates = db.prompts(statuses: [.queued], limit: 300).filter { prompt in
            (prompt.kind == .question || prompt.kind == .nudge) && isDue(prompt, now: now) && !isExpired(prompt, now: now)
        }
        let ordered = candidates.sorted { a, b in
            if a.priority != b.priority { return a.priority > b.priority }
            return a.createdAt < b.createdAt
        }
        var retired = 0
        defer { if retired > 0 { EarshotEvents.post(.prompts) } }
        for candidate in ordered {
            if subjectIsResolved(candidate) {
                var stale = candidate
                stale.status = .expired
                db.upsertPrompt(stale)
                retired += 1
                continue
            }
            return candidate
        }
        return nil
    }

    private func subjectIsResolved(_ prompt: StoredPrompt) -> Bool {
        guard let id = prompt.relatedID else { return false }
        if let insight = db.insight(id: id) { return insight.status != .open }
        if let goal = db.goal(id: id) { return goal.status != .active }
        return false
    }

    // MARK: Release

    func release(_ prompt: StoredPrompt) {
        var p = prompt
        p.status = .pending
        p.releasedAt = Date()
        p.deliveredAt = nil
        p.notBefore = nil
        db.upsertPrompt(p)
        EarshotEvents.post(.prompts)
        Log.info("QuestionScheduler: released \(p.kind.rawValue) prompt \(p.id).")
    }

    // MARK: Answers

    func handleAnswer(_ answer: PromptAnswer) async {
        guard let prompt = db.prompt(id: answer.promptID) else {
            Log.error("QuestionScheduler: answer for unknown prompt \(answer.promptID).")
            return
        }
        if prompt.status == .answered || prompt.status == .dismissed {
            Log.info("QuestionScheduler: prompt \(prompt.id) is already \(prompt.status.rawValue); ignoring the duplicate answer.")
            return
        }
        guard claim(prompt.id) else {
            Log.info("QuestionScheduler: an answer for \(prompt.id) is already being processed.")
            return
        }
        let waitsForVoice = await process(answer, for: prompt)
        unclaim(prompt.id)
        if waitsForVoice {
            // The answer may arrive after its audio (store-and-forward): try right away.
            await resolveVoiceAnswers()
        }
    }

    /// Returns true when the prompt now waits for a spoken answer.
    private func process(_ answer: PromptAnswer, for prompt: StoredPrompt) async -> Bool {
        let now = Date()
        switch answer.mode {
        case .dismissed:
            var p = prompt
            p.status = .dismissed
            p.answeredAt = answer.answeredAt
            db.upsertPrompt(p)
            EarshotEvents.post(.prompts)
            clearVoiceState(p.id)
            if p.kind == .approval { notifyApproval(p, approved: false) }
            if p.kind == .question || p.kind == .nudge { recordDismissal(kind: p.kind) }
            return false

        case .snoozed:
            snooze(prompt, now: now)
            return false

        case .voiceWindow:
            guard prompt.kind != .approval else {
                Log.info("QuestionScheduler: spoken answers are not accepted for approvals; waiting for a tap.")
                return false
            }
            var p = prompt
            p.status = .awaitingVoice
            p.answeredAt = answer.answeredAt
            db.upsertPrompt(p)
            storeVoiceState(p.id, window: answer.voiceWindowSeconds, receivedAt: now)
            EarshotEvents.post(.prompts)
            return true

        case .choice, .text:
            if prompt.kind == .approval {
                answerApproval(prompt, answer: answer)
                return false
            }
            var text = answer.text?.trimmed ?? ""
            if let choiceID = answer.choiceID, let choice = prompt.choices.first(where: { $0.id == choiceID }) {
                text = text.isEmpty ? choice.title : "\(choice.title): \(text)"
            } else if text.isEmpty, let choiceID = answer.choiceID {
                text = choiceID
            }
            if (prompt.kind == .question || prompt.kind == .nudge),
               QuestionScheduler.laterAnswers.contains(PromptLibrary.normalizedTitle(text)) {
                snooze(prompt, now: now)
                return false
            }
            await answerQuestion(prompt, text: text, choiceID: answer.choiceID, answeredAt: answer.answeredAt, spoken: false)
            return false
        }
    }

    private func answerApproval(_ prompt: StoredPrompt, answer: PromptAnswer) {
        let approved: Bool
        if let choiceID = answer.choiceID {
            approved = choiceID == "approve"
        } else {
            approved = QuestionScheduler.isAffirmative(answer.text ?? "")
        }
        var p = prompt
        p.status = .answered
        p.answerChoiceID = answer.choiceID ?? (approved ? "approve" : "deny")
        p.answerText = answer.text?.nilIfEmpty ?? (approved ? "Approve" : "Deny")
        p.answeredAt = answer.answeredAt
        db.upsertPrompt(p)
        EarshotEvents.post(.prompts)
        notifyApproval(p, approved: approved)
    }

    private func notifyApproval(_ prompt: StoredPrompt, approved: Bool) {
        let approvalID = prompt.relatedID ?? prompt.id
        guard let callback = onApprovalAnswered else {
            Log.error("QuestionScheduler: approval \(approvalID) answered but no handler is set.")
            return
        }
        callback(approvalID, approved)
    }

    private static func isAffirmative(_ text: String) -> Bool {
        let key = PromptLibrary.normalizedTitle(text)
        return affirmativeAnswers.contains(key) || key.hasPrefix("yes ")
    }

    private func snooze(_ prompt: StoredPrompt, now: Date) {
        guard prompt.kind != .approval else {
            Log.info("QuestionScheduler: approvals cannot be snoozed; leaving \(prompt.id) pending.")
            return
        }
        var p = prompt
        let notBefore = now.addingTimeInterval(QuestionScheduler.snoozeInterval)
        p.status = .queued
        p.notBefore = notBefore
        p.deliveredAt = nil
        if let expires = p.expiresAt, expires < notBefore.addingTimeInterval(3_600) {
            p.expiresAt = notBefore.addingTimeInterval(12 * 3_600)
        }
        db.upsertPrompt(p)
        clearVoiceState(p.id)
        EarshotEvents.post(.prompts)
    }

    /// Stores the user's answer and, for questions and nudges, lets the model act on it.
    private func answerQuestion(_ prompt: StoredPrompt, text: String, choiceID: String?,
                                answeredAt: Date, spoken: Bool) async {
        var p = prompt
        let answerText = text.trimmed
        p.status = .answered
        p.answerText = answerText
        p.answerChoiceID = choiceID
        p.answeredAt = answeredAt
        db.upsertPrompt(p)
        EarshotEvents.post(.prompts)
        clearVoiceState(p.id)

        guard p.kind == .question || p.kind == .nudge else { return }
        recordEngagement(kind: p.kind)
        guard !answerText.isEmpty, answerText != QuestionScheduler.noSpeech else { return }
        if QuestionScheduler.declineAnswers.contains(PromptLibrary.normalizedTitle(answerText)) { return }
        guard llm.isConfigured else {
            Log.info("QuestionScheduler: answer stored; AI is not configured, so it was not interpreted.")
            return
        }
        do {
            try await interpret(p, answer: answerText, spoken: spoken)
        } catch {
            Log.error("QuestionScheduler: could not interpret the answer to \(p.id): \(error.localizedDescription)")
        }
    }

    // MARK: Interpretation

    private func interpret(_ prompt: StoredPrompt, answer: String, spoken: Bool) async throws {
        let settings = SettingsStore.current
        let now = Date()
        let goals = db.goals(statuses: [.active])
        let openItems = db.insights(statuses: [.open], kinds: [.task, .commitment, .event, .goal, .idea, .question],
                                    since: nil, limit: 80)
        let choicesOffered = prompt.choices.isEmpty ? "(free answer)" : prompt.choices.map { $0.title }.joined(separator: " | ")
        let mode = spoken
            ? "spoken: transcribed from ambient audio, so it may be partial, garbled or include other voices"
            : (prompt.answerChoiceID != nil ? "tapped choice" : "typed or dictated text")
        let askedAt = (prompt.releasedAt ?? prompt.createdAt).shortText
        let openList = openItems.isEmpty ? "(none)" : openItems.map { PromptLibrary.itemLine($0) }.joined(separator: "\n")

        let user = """
        <now>\(PromptLibrary.nowLine(now))</now>

        <profile>
        \(settings.profileBlock)
        </profile>

        <active_goals>
        \(PromptLibrary.goalsBlock(goals))
        </active_goals>

        <open_tasks>
        \(openList)
        </open_tasks>

        <question kind="\(prompt.kind.rawValue)" asked="\(askedAt)">\(prompt.title)</question>
        <why_asked>\(prompt.rationale.nilIfEmpty ?? "(not recorded)")</why_asked>
        <related_item>
        \(relatedDescription(prompt.relatedID))
        </related_item>
        <choices_offered>\(choicesOffered)</choices_offered>
        <answer mode="\(mode)" at="\((prompt.answeredAt ?? now).shortText)">\(answer.clipped(2_000))</answer>

        Interpret the answer as instructed and return the JSON.
        """

        let reply = try await llm.completeJSON(system: PromptLibrary.answerInterpreterSystem, user: user,
                                               schema: PromptLibrary.answerInterpreterSchema,
                                               tier: .foreground, maxTokens: 8_000)
        apply(reply, to: prompt, answer: answer, goals: goals, openItems: openItems)
    }

    private func relatedDescription(_ relatedID: String?) -> String {
        guard let id = relatedID else { return "(none)" }
        if let insight = db.insight(id: id) {
            var text = PromptLibrary.itemLine(insight)
            if let detail = insight.detail.nilIfEmpty { text += "\n" + detail.clipped(500) }
            return text
        }
        if let goal = db.goal(id: id) {
            return "Goal: " + PromptLibrary.goalsBlock([goal])
        }
        return "(none)"
    }

    private func apply(_ reply: JSONValue, to prompt: StoredPrompt, answer: String, goals: [Goal], openItems: [Insight]) {
        let now = Date()
        var goalsChanged = false
        var insightsChanged = false
        var promptsChanged = false

        // A new goal the user wants to pursue.
        var newGoal: Goal?
        let goalTitle = PromptLibrary.text(reply["create_goal"]?["title"])
        if !goalTitle.isEmpty {
            let allGoals = db.goals(statuses: nil)
            if let index = PromptLibrary.bestMatch(goalTitle, among: allGoals.map({ $0.title }), threshold: 0.75) {
                var existing = allGoals[index]
                if existing.status != .active {
                    existing.status = .active
                    existing.lastCheckIn = now
                    db.upsertGoal(existing)
                    goalsChanged = true
                }
                newGoal = existing
            } else {
                var goal = Goal.make(title: goalTitle.clipped(100),
                                     why: PromptLibrary.text(reply["create_goal"]?["why"]).clipped(400))
                goal.lastCheckIn = now
                db.upsertGoal(goal)
                newGoal = goal
                goalsChanged = true
                Log.info("QuestionScheduler: created goal \(goal.id) from an answer.")
            }
        }

        // A progress note on a goal.
        let noteText = PromptLibrary.text(reply["goal_note"]?["note"])
        if !noteText.isEmpty {
            var pool = goals
            if let created = newGoal, !pool.contains(where: { $0.id == created.id }) { pool.append(created) }
            let noteGoalTitle = PromptLibrary.text(reply["goal_note"]?["goal_title"])
            var target: Goal?
            if !noteGoalTitle.isEmpty, let index = PromptLibrary.bestMatch(noteGoalTitle, among: pool.map({ $0.title }), threshold: 0.75) {
                target = pool[index]
            } else if noteGoalTitle.isEmpty {
                target = newGoal ?? pool.first(where: { $0.id == prompt.relatedID })
            }
            if let found = target, var goal = db.goal(id: found.id) ?? Optional(found) {
                goal.notes.append(GoalNote(date: now, text: noteText.clipped(400)))
                goal.lastCheckIn = now
                db.upsertGoal(goal)
                goalsChanged = true
            }
        }

        // A task the user says is already done.
        var markedDone = false
        let doneTitle = PromptLibrary.text(reply["insight_title_done"])
        if !doneTitle.isEmpty,
           let index = PromptLibrary.bestMatch(doneTitle, among: openItems.map({ $0.title }), threshold: 0.7),
           var item = db.insight(id: openItems[index].id) ?? Optional(openItems[index]),
           item.status == .open {
            item.status = .done
            db.upsertInsight(item)
            insightsChanged = true
            markedDone = true
        }

        // Concrete help the user agreed to.
        let sourceInsightID: String? = prompt.relatedID.flatMap { db.insight(id: $0) != nil ? $0 : nil }
        var actionKeys = db.actions(statuses: nil, limit: 200).map { PromptLibrary.normalizedTitle($0.title) }
        var newActions: [ProposedAction] = []
        for raw in reply["actions"]?.arrayValue ?? [] {
            if newActions.count >= 3 { break }
            guard let action = PromptLibrary.makeAction(from: raw, sourceInsightID: sourceInsightID),
                  !PromptLibrary.isDuplicate(action.title, ofNormalized: actionKeys, threshold: 0.75) else { continue }
            db.upsertAction(action)
            newActions.append(action)
            actionKeys.append(PromptLibrary.normalizedTitle(action.title))
        }

        // A follow-up for tomorrow.
        let followUp = PromptLibrary.text(reply["follow_up_question"]).clipped(140)
        if !followUp.isEmpty {
            let liveKeys = db.prompts(statuses: [.queued, .pending, .delivered], limit: 200).map { PromptLibrary.normalizedTitle($0.title) }
            if !PromptLibrary.isDuplicate(followUp, ofNormalized: liveKeys, threshold: 0.7) {
                let notBefore = now.addingTimeInterval(QuestionScheduler.followUpDelay)
                let base = max(1, prompt.priority - 1)
                let priority = max(1, base - PromptLibrary.dismissalPenalty(db: db, kind: .question))
                let rationale = "Following up on “\(prompt.title.clipped(80))”; you answered “\(answer.clipped(80))”."
                let next = StoredPrompt.make(kind: .question, title: followUp, body: "",
                                             choices: PromptLibrary.makeChoices(PromptLibrary.strings(reply["follow_up_choices"])),
                                             allowsFreeText: true, allowsVoice: true, priority: priority,
                                             status: .queued, rationale: rationale,
                                             relatedID: newGoal?.id ?? prompt.relatedID,
                                             expiresAt: notBefore.addingTimeInterval(QuestionScheduler.questionLifetime),
                                             notBefore: notBefore)
                db.upsertPrompt(next)
                promptsChanged = true
            }
        }

        if goalsChanged { EarshotEvents.post(.goals) }
        if insightsChanged { EarshotEvents.post(.insights) }
        if !newActions.isEmpty { EarshotEvents.post(.actions) }
        if promptsChanged { EarshotEvents.post(.prompts) }

        // A short acknowledgement only when something actually happened (keeps the wrist quiet).
        let acknowledgement = PromptLibrary.text(reply["acknowledgement"])
        if !acknowledgement.isEmpty && (goalsChanged || markedDone || !newActions.isEmpty) {
            let info = StoredPrompt.make(kind: .info, title: acknowledgement.clipped(100), body: "",
                                         choices: [], allowsFreeText: false, allowsVoice: false, priority: 1,
                                         status: .queued,
                                         rationale: "Acknowledges your answer to “\(prompt.title.clipped(80))”.",
                                         relatedID: prompt.id, expiresAt: now.addingTimeInterval(6 * 3_600))
            release(info)
        }

        Log.info("QuestionScheduler: answer to \(prompt.id) → \(newActions.count) action(s), goals changed: \(goalsChanged), task done: \(markedDone).")
        if !newActions.isEmpty, let callback = onNewActions {
            callback(newActions)
        }
    }

    // MARK: Learning

    private func recordDismissal(kind: PromptKind) {
        let key = PromptLibrary.dismissalKey(kind)
        let count = (Int(db.kvGet(key) ?? "") ?? 0) + 1
        db.kvSet(key, String(count))
        guard count == 3 else { return }
        // The user keeps waving these away: make the ones already waiting less pushy too.
        var lowered = 0
        for var prompt in db.prompts(statuses: [.queued], limit: 300) where prompt.kind == kind && prompt.priority > 1 {
            prompt.priority -= 1
            db.upsertPrompt(prompt)
            lowered += 1
        }
        Log.info("QuestionScheduler: 3 \(kind.rawValue) prompts dismissed; lowered priority of \(lowered) queued one(s).")
        if lowered > 0 { EarshotEvents.post(.prompts) }
    }

    private func recordEngagement(kind: PromptKind) {
        let key = PromptLibrary.dismissalKey(kind)
        let count = Int(db.kvGet(key) ?? "") ?? 0
        if count > 0 { db.kvSet(key, String(count - 1)) }
    }

    // MARK: Voice answers

    func resolveVoiceAnswers() async {
        let started: Bool = locked {
            if resolvingVoice { return false }
            resolvingVoice = true
            return true
        }
        guard started else { return }
        defer { locked { resolvingVoice = false } }

        let waiting = db.prompts(statuses: [.awaitingVoice], limit: 50)
        guard !waiting.isEmpty else { return }
        for prompt in waiting {
            guard claim(prompt.id) else { continue }
            if let text = spokenAnswer(for: prompt, now: Date()) {
                Log.info("QuestionScheduler: spoken answer for \(prompt.id) finalised (\(PromptLibrary.wordCount(text)) words).")
                await answerQuestion(prompt, text: text, choiceID: nil,
                                     answeredAt: prompt.answeredAt ?? Date(), spoken: true)
            }
            unclaim(prompt.id)
        }
    }

    /// The transcript of the voice window once it is final, nil while still waiting.
    private func spokenAnswer(for prompt: StoredPrompt, now: Date) -> String? {
        let state = voiceState(prompt.id)
        let answeredAt = prompt.answeredAt ?? state.receivedAt ?? now
        let windowEnd = answeredAt.addingTimeInterval(state.window)
        let receivedAt = state.receivedAt ?? answeredAt
        let waited = now.timeIntervalSince(max(answeredAt, receivedAt))

        if waited < QuestionScheduler.voiceHardLimit {
            guard now >= windowEnd else { return nil }
            let pending = transcriptionPending(from: answeredAt, to: windowEnd)
            let laterSpeech = db.utterances(from: windowEnd, to: now.addingTimeInterval(60), limit: 20)
                .contains(where: { $0.startedAt > windowEnd })
            let finished = !pending && (laterSpeech || waited >= QuestionScheduler.voiceGrace)
            guard finished else { return nil }
        }

        let from = answeredAt.addingTimeInterval(-2)
        let to = windowEnd.addingTimeInterval(3)
        let text = db.utterances(from: from, to: to, limit: 50)
            .filter { $0.startedAt >= from && $0.startedAt <= to }
            .map { $0.text.trimmed }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return text.isEmpty ? QuestionScheduler.noSpeech : text
    }

    /// True while audio overlapping the window is stored but not transcribed yet.
    private func transcriptionPending(from start: Date, to end: Date) -> Bool {
        db.segments(from: start.addingTimeInterval(-900), to: end).contains(where: { segment in
            (segment.status == .received || segment.status == .transcribing)
                && segment.startedAt <= end && segment.endedAt >= start
        })
    }

    private func voiceKey(_ promptID: String) -> String { "voice.\(promptID)" }

    private func storeVoiceState(_ promptID: String, window: Double?, receivedAt: Date) {
        var seconds = QuestionScheduler.defaultVoiceWindow
        if let window, window.isFinite, window > 0 { seconds = min(max(window, 3), 120) }
        db.kvSet(voiceKey(promptID), "\(seconds)|\(receivedAt.timeIntervalSince1970)")
    }

    private func voiceState(_ promptID: String) -> (window: TimeInterval, receivedAt: Date?) {
        guard let raw = db.kvGet(voiceKey(promptID)) else { return (QuestionScheduler.defaultVoiceWindow, nil) }
        let parts = raw.split(separator: "|").map(String.init)
        var window = QuestionScheduler.defaultVoiceWindow
        if let first = parts.first, let value = Double(first), value.isFinite, value > 0 {
            window = min(max(value, 3), 120)
        }
        var receivedAt: Date?
        if parts.count > 1, let value = Double(parts[1]), value.isFinite {
            receivedAt = Date(timeIntervalSince1970: value)
        }
        return (window, receivedAt)
    }

    private func clearVoiceState(_ promptID: String) {
        db.kvSet(voiceKey(promptID), nil)
    }
}
