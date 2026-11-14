//  InsightEngine.swift
//  Periodically reads the new part of the transcript and turns it into
//  insights, queued check-in questions, proposed Mac actions and goal notes.

import Foundation

/// Everything already known that the model needs to avoid duplicates.
private struct InsightAnalysisContext {
    var goals: [Goal]
    var openItems: [Insight]
    var recentItems: [Insight]
    var prompts: [StoredPrompt]
    var actions: [ProposedAction]
    var bookmarks: [StoredBookmark]
}

final class InsightEngine: @unchecked Sendable {
    private let db: Database
    private let llm: LLMService

    private let lock = NSLock()
    private var running = false
    private var storedLastRunAt: Date?
    private var storedLastError: String?
    private var storedOnNewActions: (@Sendable ([ProposedAction]) -> Void)?
    /// Consecutive non-transient failures on the same cursor (a batch the model keeps rejecting).
    private var failingCursor: Int64 = -1
    private var failingCount = 0

    private static let cursorKey = "insights.cursor"
    private static let summaryKey = "insights.lastSummary"
    private static let summaryAtKey = "insights.lastSummaryAt"
    private static let batchLimit = 600
    private static let maxBatchesPerRun = 3
    private static let questionLifetime: TimeInterval = 36 * 3_600
    private static let maxItemsPerPass = 12
    private static let maxQuestionsPerPass = 3
    private static let maxActionsPerPass = 3
    /// Above this many queued questions only priority ≥ 4 candidates are added.
    private static let queueSoftLimit = 15

    init(db: Database, llm: LLMService) {
        self.db = db
        self.llm = llm
    }

    // MARK: Public state

    var onNewActions: (@Sendable ([ProposedAction]) -> Void)? {
        get { locked { storedOnNewActions } }
        set { locked { storedOnNewActions = newValue } }
    }

    var isRunning: Bool { locked { running } }
    var lastRunAt: Date? { locked { storedLastRunAt } }
    var lastError: String? { locked { storedLastError } }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: Analysis

    @discardableResult
    func analyzeIfNeeded(force: Bool) async -> Int {
        let started: Bool = locked {
            if running { return false }
            running = true
            return true
        }
        guard started else { return 0 }
        defer { locked { running = false } }

        guard llm.isConfigured else {
            let message = "AI is not configured. Add an Anthropic API key in Settings → AI."
            let changed: Bool = locked {
                if storedLastError == message { return false }
                storedLastError = message
                return true
            }
            if changed {
                Log.info("InsightEngine: \(message)")
                EarshotEvents.post(.status)
            }
            return 0
        }

        var created = 0
        var attempted = false
        defer { if attempted { EarshotEvents.post(.status) } }
        for _ in 0..<InsightEngine.maxBatchesPerRun {
            let settings = SettingsStore.current
            let cursor = Int64(db.kvGet(InsightEngine.cursorKey) ?? "0") ?? 0
            let batch = db.utterances(afterID: cursor, limit: InsightEngine.batchLimit)
            guard let lastID = batch.map({ $0.id }).max(), lastID > cursor else { break }
            let spoken = batch.filter { !$0.text.trimmed.isEmpty }
            let words = spoken.reduce(0) { $0 + PromptLibrary.wordCount($1.text) }
            if words == 0 {
                advanceCursor(to: lastID)
                continue
            }
            if !force && words < max(1, settings.analysisMinWords) {
                Log.debug("InsightEngine: \(words) new words, waiting for \(settings.analysisMinWords).")
                break
            }
            attempted = true
            do {
                created += try await analyze(spoken, settings: settings)
                advanceCursor(to: lastID)
                locked {
                    storedLastRunAt = Date()
                    storedLastError = nil
                    failingCursor = -1
                    failingCount = 0
                }
            } catch {
                handleFailure(error, cursor: cursor, lastID: lastID)
                break
            }
            if batch.count < InsightEngine.batchLimit { break }
        }
        return created
    }

    private func advanceCursor(to id: Int64) {
        db.kvSet(InsightEngine.cursorKey, String(id))
    }

    private func handleFailure(_ error: Error, cursor: Int64, lastID: Int64) {
        let message = error.localizedDescription
        Log.error("InsightEngine: analysis failed: \(message)")
        let permanent = InsightEngine.isPermanent(error)
        let skip: Bool = locked {
            storedLastError = message
            guard permanent else { return false }
            if failingCursor == cursor {
                failingCount += 1
            } else {
                failingCursor = cursor
                failingCount = 1
            }
            if failingCount >= 3 {
                failingCursor = -1
                failingCount = 0
                return true
            }
            return false
        }
        if skip {
            Log.error("InsightEngine: skipping utterances \(cursor + 1)...\(lastID) after repeated failures.")
            advanceCursor(to: lastID)
        }
    }

    /// Errors that will not go away by retrying the same transcript (refusals, malformed replies).
    private static func isPermanent(_ error: Error) -> Bool {
        if error is CancellationError || error is URLError { return false }
        guard let claude = error as? ClaudeError else { return true }
        switch claude {
        case .refusal, .truncated, .invalidResponse:
            return true
        case .http(let status, _, _):
            return status == 400 || status == 413
        case .missingAPIKey:
            return false
        }
    }

    private func analyze(_ utterances: [Utterance], settings: AppSettings) async throws -> Int {
        let now = Date()
        let windowStart = utterances.map { $0.startedAt }.min() ?? now
        let windowEnd = utterances.map { $0.endedAt }.max() ?? now
        let context = loadContext(now: now, windowStart: windowStart, windowEnd: windowEnd)
        let words = utterances.reduce(0) { $0 + PromptLibrary.wordCount($1.text) }
        let user = buildPrompt(utterances: utterances, context: context, settings: settings, now: now,
                               windowStart: windowStart, windowEnd: windowEnd, words: words)
        Log.info("InsightEngine: analysing \(utterances.count) utterances (\(words) words).")
        let reply = try await llm.completeJSON(system: PromptLibrary.analysisSystem, user: user,
                                               schema: PromptLibrary.analysisSchema,
                                               tier: .background, maxTokens: 16_000)
        return apply(reply, utterances: utterances, context: context,
                     windowStart: windowStart, windowEnd: windowEnd)
    }

    private func loadContext(now: Date, windowStart: Date, windowEnd: Date) -> InsightAnalysisContext {
        let goals = db.goals(statuses: [.active])
        let openItems = db.insights(statuses: [.open], kinds: nil, since: nil, limit: 300)
        let recentItems = db.insights(statuses: nil, kinds: nil, since: now.addingTimeInterval(-3 * 86_400), limit: 400)
        var prompts = db.prompts(statuses: [.queued, .pending, .delivered, .awaitingVoice], limit: 200)
        var seen = Set(prompts.map { $0.id })
        for p in db.prompts(since: now.addingTimeInterval(-4 * 86_400), limit: 200) where !seen.contains(p.id) {
            prompts.append(p)
            seen.insert(p.id)
        }
        let actions = db.actions(statuses: nil, limit: 200)
        let bookmarks = db.bookmarks(from: windowStart.addingTimeInterval(-180), to: windowEnd.addingTimeInterval(60))
            .filter { $0.kind == .bookmark }
        return InsightAnalysisContext(goals: goals, openItems: openItems, recentItems: recentItems,
                               prompts: prompts, actions: actions, bookmarks: bookmarks)
    }

    private func buildPrompt(utterances: [Utterance], context: InsightAnalysisContext, settings: AppSettings, now: Date,
                             windowStart: Date, windowEnd: Date, words: Int) -> String {
        let openIDs = Set(context.openItems.map { $0.id })
        let openLoops = context.openItems.filter { $0.kind == .task || $0.kind == .commitment }
        let otherOpen = context.openItems.filter { $0.kind != .task && $0.kind != .commitment }
        let recentOther = context.recentItems.filter { !openIDs.contains($0.id) }

        var tracked: [String] = []
        tracked.append("Open tasks and commitments:")
        tracked.append(openLoops.isEmpty ? "(none)" : openLoops.prefix(60).map { PromptLibrary.itemLine($0) }.joined(separator: "\n"))
        tracked.append("Other items already captured:")
        let others = Array(otherOpen.prefix(40)) + Array(recentOther.prefix(40))
        tracked.append(others.isEmpty ? "(none)" : others.map { PromptLibrary.itemLine($0) }.joined(separator: "\n"))
        tracked.append("Check-in questions already queued or asked recently:")
        let questions = context.prompts.filter { $0.kind == .question || $0.kind == .nudge }.prefix(30)
        tracked.append(questions.isEmpty ? "(none)" : questions.map { "- \($0.title) [\($0.status.rawValue)]" }.joined(separator: "\n"))
        tracked.append("Actions already proposed or handled:")
        let actions = context.actions.prefix(30)
        tracked.append(actions.isEmpty ? "(none)" : actions.map { "- \($0.title) [\($0.kind.rawValue), \($0.status.rawValue)]" }.joined(separator: "\n"))

        let bookmarkLines: String
        if context.bookmarks.isEmpty {
            bookmarkLines = "(none in this stretch)"
        } else {
            bookmarkLines = context.bookmarks.map { b -> String in
                if let note = b.note?.nilIfEmpty { return "- \(b.at.timeText) (note: \(note.clipped(200)))" }
                return "- \(b.at.timeText)"
            }.joined(separator: "\n")
        }

        let transcript = PromptLibrary.transcriptBlock(utterances, now: now)
        return """
        <now>\(PromptLibrary.nowLine(now))</now>

        <profile>
        \(settings.profileBlock)
        </profile>

        <active_goals>
        \(PromptLibrary.goalsBlock(context.goals))
        </active_goals>

        <already_tracked>
        \(tracked.joined(separator: "\n"))
        </already_tracked>

        <bookmarks>
        \(bookmarkLines)
        </bookmarks>

        <transcript from="\(windowStart.shortText)" to="\(windowEnd.shortText)" words="\(words)">
        \(transcript)
        </transcript>

        Analyse this stretch as instructed and return the JSON.
        """
    }

    // MARK: Applying the reply

    private func apply(_ reply: JSONValue, utterances: [Utterance], context: InsightAnalysisContext,
                       windowStart: Date, windowEnd: Date) -> Int {
        let now = Date()

        // Summary (TodayBuilder's headline before the daily digest exists).
        let summary = PromptLibrary.text(reply["summary"])
        if !summary.isEmpty {
            db.kvSet(InsightEngine.summaryKey, summary.clipped(400))
            db.kvSet(InsightEngine.summaryAtKey, String(now.timeIntervalSince1970))
        }

        // Insights
        var itemKeys = (context.openItems + context.recentItems).map { PromptLibrary.normalizedTitle($0.title) }
        var newInsights: [Insight] = []
        var moodCount = 0
        for raw in reply["items"]?.arrayValue ?? [] {
            if newInsights.count >= InsightEngine.maxItemsPerPass { break }
            guard let kind = InsightKind(rawValue: PromptLibrary.text(raw["kind"]).lowercased()) else { continue }
            let title = PromptLibrary.text(raw["title"]).clipped(120)
            guard !title.isEmpty else { continue }
            let confidence = min(1, max(0, PromptLibrary.number(raw["confidence"]) ?? 0.6))
            guard confidence >= 0.3 else { continue }
            if kind == .mood {
                if moodCount >= 1 { continue }
                moodCount += 1
            }
            guard !PromptLibrary.isDuplicate(title, ofNormalized: itemKeys) else { continue }
            var detail = PromptLibrary.text(raw["detail"])
            let quote = PromptLibrary.text(raw["quote"])
            if !quote.isEmpty {
                detail += (detail.isEmpty ? "" : "\n\n") + "“\(quote.clipped(200))”"
            }
            let source = InsightEngine.locate(quote: quote, in: utterances)
            let insight = Insight(id: UUID().uuidString, kind: kind, title: title, detail: detail,
                                  dueAt: DateParsing.parse(PromptLibrary.text(raw["due_iso"])),
                                  people: Array(PromptLibrary.strings(raw["people"]).prefix(8)),
                                  sourceFrom: source?.from ?? windowStart, sourceTo: source?.to ?? windowEnd,
                                  status: .open, confidence: confidence, createdAt: now)
            newInsights.append(insight)
            itemKeys.append(PromptLibrary.normalizedTitle(title))
        }

        // Questions and nudges (queued; the scheduler decides when to ask)
        var promptKeys = context.prompts.map { PromptLibrary.normalizedTitle($0.title) }
        let queuedCount = context.prompts.filter { $0.status == .queued && ($0.kind == .question || $0.kind == .nudge) }.count
        var newPrompts: [StoredPrompt] = []
        for raw in reply["questions"]?.arrayValue ?? [] {
            if newPrompts.count >= InsightEngine.maxQuestionsPerPass { break }
            let question = PromptLibrary.text(raw["question"]).clipped(140)
            guard !question.isEmpty,
                  !PromptLibrary.isDuplicate(question, ofNormalized: promptKeys, threshold: 0.7) else { continue }
            let kind: PromptKind = PromptLibrary.text(raw["kind"]).lowercased() == "nudge" ? .nudge : .question
            let requested = PromptLibrary.clampedInt(raw["priority"], 1...5, default: 3)
            let priority = max(1, requested - PromptLibrary.dismissalPenalty(db: db, kind: kind))
            if queuedCount + newPrompts.count >= InsightEngine.queueSoftLimit && priority < 4 { continue }
            let related = relatedTarget(PromptLibrary.text(raw["related_title"]), newInsights: newInsights, context: context)
            var expires = now.addingTimeInterval(InsightEngine.questionLifetime)
            if let due = related.dueAt, due > now.addingTimeInterval(30 * 60), due < expires {
                expires = due
            }
            let prompt = StoredPrompt.make(kind: kind, title: question, body: "",
                                           choices: PromptLibrary.makeChoices(PromptLibrary.strings(raw["choices"])),
                                           allowsFreeText: true, allowsVoice: true, priority: priority,
                                           status: .queued, rationale: PromptLibrary.text(raw["why"]).clipped(300),
                                           relatedID: related.id, expiresAt: expires, notBefore: nil)
            newPrompts.append(prompt)
            promptKeys.append(PromptLibrary.normalizedTitle(question))
        }

        // Proposed actions
        var actionKeys = context.actions.map { PromptLibrary.normalizedTitle($0.title) }
        let newTitles = newInsights.map { $0.title }
        var newActions: [ProposedAction] = []
        for raw in reply["actions"]?.arrayValue ?? [] {
            if newActions.count >= InsightEngine.maxActionsPerPass { break }
            let actionTitle = PromptLibrary.text(raw["title"])
            let sourceID = PromptLibrary.bestMatch(actionTitle, among: newTitles, threshold: 0.4).map { newInsights[$0].id }
            guard let action = PromptLibrary.makeAction(from: raw, sourceInsightID: sourceID),
                  !PromptLibrary.isDuplicate(action.title, ofNormalized: actionKeys, threshold: 0.75) else { continue }
            newActions.append(action)
            actionKeys.append(PromptLibrary.normalizedTitle(action.title))
        }

        // Goal notes
        var updatedGoals: [String: Goal] = [:]
        var goalNotes = 0
        let goalTitles = context.goals.map { $0.title }
        for raw in reply["goal_updates"]?.arrayValue ?? [] {
            let goalTitle = PromptLibrary.text(raw["goal_title"])
            let note = PromptLibrary.text(raw["note"])
            guard !goalTitle.isEmpty, !note.isEmpty,
                  let index = PromptLibrary.bestMatch(goalTitle, among: goalTitles, threshold: 0.75) else { continue }
            let goalID = context.goals[index].id
            guard var goal = updatedGoals[goalID] ?? db.goal(id: goalID) ?? Optional(context.goals[index]),
                  goal.status == .active else { continue }
            let noteKey = PromptLibrary.normalizedTitle(note)
            if goal.notes.suffix(5).contains(where: { PromptLibrary.normalizedTitle($0.text) == noteKey }) { continue }
            goal.notes.append(GoalNote(date: now, text: note.clipped(400)))
            goal.lastCheckIn = now
            updatedGoals[goalID] = goal
            goalNotes += 1
        }

        // Persist and notify
        for insight in newInsights { db.upsertInsight(insight) }
        for prompt in newPrompts { db.upsertPrompt(prompt) }
        for action in newActions { db.upsertAction(action) }
        for goal in updatedGoals.values { db.upsertGoal(goal) }

        if !newInsights.isEmpty || !summary.isEmpty { EarshotEvents.post(.insights) }
        if !newPrompts.isEmpty { EarshotEvents.post(.prompts) }
        if !newActions.isEmpty { EarshotEvents.post(.actions) }
        if !updatedGoals.isEmpty { EarshotEvents.post(.goals) }

        Log.info("InsightEngine: \(newInsights.count) insights, \(newPrompts.count) questions, \(newActions.count) actions, \(goalNotes) goal notes.")

        if !newActions.isEmpty, let callback = onNewActions {
            callback(newActions)
        }
        return newInsights.count + newPrompts.count + newActions.count + goalNotes
    }

    /// The item or goal a question refers to: (id, due date of the item if any).
    private func relatedTarget(_ title: String, newInsights: [Insight], context: InsightAnalysisContext) -> (id: String?, dueAt: Date?) {
        guard !title.isEmpty else { return (nil, nil) }
        let candidates = newInsights + context.openItems
        if let index = PromptLibrary.bestMatch(title, among: candidates.map({ $0.title }), threshold: 0.6) {
            return (candidates[index].id, candidates[index].dueAt)
        }
        if let index = PromptLibrary.bestMatch(title, among: context.goals.map({ $0.title }), threshold: 0.6) {
            return (context.goals[index].id, nil)
        }
        return (nil, nil)
    }

    /// Narrows an insight's source to the utterance containing its supporting quote (±30 s).
    private static func locate(quote: String, in utterances: [Utterance]) -> (from: Date, to: Date)? {
        let words = PromptLibrary.normalizedTitle(quote).split(separator: " ")
        guard words.count >= 2 else { return nil }
        let needle = words.prefix(6).joined(separator: " ")
        for u in utterances where PromptLibrary.normalizedTitle(u.text).contains(needle) {
            return (u.startedAt.addingTimeInterval(-30), u.endedAt.addingTimeInterval(30))
        }
        return nil
    }
}
