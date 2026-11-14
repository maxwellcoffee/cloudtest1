//  DigestEngine.swift
//  End-of-day digests and weekly reviews, written in the companion's voice.

import Foundation

private enum DigestEngineError: LocalizedError {
    case notConfigured
    case nothingToSummarise(String)
    case emptyReply

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI is not configured. Add an Anthropic API key in Settings → AI."
        case .nothingToSummarise(let what):
            return "There is nothing to summarise for \(what) yet."
        case .emptyReply:
            return "The model returned an empty digest."
        }
    }
}

final class DigestEngine: @unchecked Sendable {
    private let db: Database
    private let llm: LLMService
    private let calendar: CalendarService

    private let lock = NSLock()
    private var scheduledRunning = false
    /// Last failed attempt per digest key, so a failing schedule retries every 30 minutes, not every tick.
    private var failedAttempts: [String: Date] = [:]

    private static let dailyLastRunKey = "digest.daily.lastRun"
    private static let weeklyLastRunKey = "digest.weekly.lastRun"
    /// Days longer than this are condensed in chunks first.
    private static let chunkWords = 12_000
    private static let maxConcurrentChunks = 3
    private static let retryInterval: TimeInterval = 30 * 60
    private static let minimumWords = 50

    /// (chunk index, condensed text or the error) produced by one concurrent chunk task.
    private typealias ChunkOutcome = (Int, Result<String, Error>)

    init(db: Database, llm: LLMService, calendar: CalendarService) {
        self.db = db
        self.llm = llm
        self.calendar = calendar
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    // MARK: Daily digest

    func generateDaily(for day: Date) async throws -> Digest {
        guard llm.isConfigured else { throw DigestEngineError.notConfigured }
        let now = Date()
        let start = day.startOfDay
        let end = day.endOfDay
        let dayName = PromptLibrary.formatted(day, template: "EEEE MMMM d yyyy")

        let utterances = db.utterances(from: start, to: end, limit: 60_000).filter { !$0.text.trimmed.isEmpty }
        let captured = db.insights(statuses: nil, kinds: nil, since: start, limit: 1_000)
            .filter { $0.createdAt < end && $0.status != .dismissed }
        guard !utterances.isEmpty || !captured.isEmpty else {
            throw DigestEngineError.nothingToSummarise(dayName)
        }

        let bookmarks = db.bookmarks(from: start, to: end).filter { $0.kind == .bookmark }
        let totalWords = utterances.reduce(0) { $0 + PromptLibrary.wordCount($1.text) }
        let recordedSeconds = db.recordedSeconds(from: start, to: end)
        let minutes = recordedSeconds.isFinite ? Int((max(0, recordedSeconds) / 60).rounded()) : 0

        let material: String
        let materialTag: String
        if totalWords > DigestEngine.chunkWords {
            Log.info("DigestEngine: \(totalWords) words on \(day.dayKey); condensing in chunks first.")
            material = try await condenseInChunks(utterances, bookmarks: bookmarks, now: now)
            materialTag = "notes_condensing_the_day"
        } else {
            material = utterances.isEmpty ? "(no speech was transcribed)" : PromptLibrary.transcriptBlock(utterances, now: now)
            materialTag = "transcript"
        }

        let goals = db.goals(statuses: [.active])
        let stillOpen = db.insights(statuses: [.open], kinds: [.task, .commitment, .event], since: nil, limit: 60)
            .filter { $0.createdAt < start }
        let checkIns = db.prompts(since: start, limit: 200).filter { p -> Bool in
            guard p.kind == .question || p.kind == .nudge, p.status == .answered,
                  let answered = p.answeredAt else { return false }
            return answered >= start && answered < end
        }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? end
        let tomorrowEvents = calendar.events(on: tomorrow).sorted { $0.start < $1.start }

        let isToday = Calendar.current.isDate(day, inSameDayAs: now)
        let dayLine = isToday ? "\(dayName) (today)" : dayName
        let stillOpenText = stillOpen.isEmpty
            ? "(none)"
            : stillOpen.map { PromptLibrary.itemLine($0) }.joined(separator: "\n")
        let user = """
        <day>\(dayLine)</day>
        <now>\(PromptLibrary.nowLine(now))</now>

        <profile>
        \(SettingsStore.current.profileBlock)
        </profile>

        <stats>About \(totalWords) words heard; \(minutes) minutes recorded.</stats>

        <active_goals>
        \(goalsWithTodaysNotes(goals, from: start, to: end))
        </active_goals>

        <captured_that_day>
        \(DigestEngine.groupedItems(captured))
        </captured_that_day>

        <still_open_from_earlier>
        \(stillOpenText)
        </still_open_from_earlier>

        <check_ins_answered>
        \(DigestEngine.checkInLines(checkIns))
        </check_ins_answered>

        <bookmarks>
        \(DigestEngine.bookmarkLines(bookmarks))
        </bookmarks>

        <tomorrow_calendar>
        \(DigestEngine.eventLines(tomorrowEvents))
        </tomorrow_calendar>

        <\(materialTag)>
        \(material)
        </\(materialTag)>

        Write the daily digest now.
        """

        let markdown = try await llm.complete(system: PromptLibrary.dailyDigestSystem, user: user,
                                              tier: .foreground, maxTokens: 12_000).trimmed
        guard !markdown.isEmpty else { throw DigestEngineError.emptyReply }

        let digest = Digest(day: day.dayKey, markdown: markdown, createdAt: Date())
        db.upsertDigest(digest)
        EarshotEvents.post(.digests)

        var brief = PromptLibrary.digestBrief(markdown, sentences: 2)
        if brief.isEmpty { brief = "Your digest is ready on your Mac." }
        if !isToday {
            let label = Calendar.current.isDateInYesterday(day) ? "Yesterday" : PromptLibrary.formatted(day, template: "EEE MMM d")
            brief = "\(label): \(brief)"
        }
        releaseDigestPrompt(title: "Your day in brief", body: brief, relatedID: digest.day,
                            rationale: "Daily digest for \(dayName).")
        Log.info("DigestEngine: daily digest for \(digest.day) stored (\(PromptLibrary.wordCount(markdown)) words).")
        return digest
    }

    // MARK: Weekly review

    func generateWeekly(endingOn day: Date) async throws -> Digest {
        guard llm.isConfigured else { throw DigestEngineError.notConfigured }
        let now = Date()
        let cal = Calendar.current
        let end = day.endOfDay
        let start = cal.date(byAdding: .day, value: -6, to: day.startOfDay) ?? day.startOfDay.addingTimeInterval(-6 * 86_400)
        let rangeLabel = "\(PromptLibrary.formatted(start, template: "EEE MMM d"))–\(PromptLibrary.formatted(day, template: "EEE MMM d yyyy"))"

        var dailies: [Digest] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -offset, to: day.startOfDay) else { continue }
            if let digest = db.digest(day: date.dayKey) { dailies.append(digest) }
        }
        let captured = db.insights(statuses: nil, kinds: nil, since: start, limit: 1_000)
            .filter { $0.createdAt < end && $0.status != .dismissed }
        guard !dailies.isEmpty || !captured.isEmpty else {
            throw DigestEngineError.nothingToSummarise("the week of \(rangeLabel)")
        }

        let allGoals = db.goals(statuses: nil)
        let relevantGoals = allGoals.filter { goal in
            goal.status == .active || goal.notes.contains(where: { $0.date >= start && $0.date < end })
        }
        let goalLines: String
        if relevantGoals.isEmpty {
            goalLines = "(no goals yet)"
        } else {
            goalLines = relevantGoals.map { goal -> String in
                var line = "- \(goal.title) [\(goal.status.rawValue)]"
                if let why = goal.why.nilIfEmpty { line += " (why: \(why.clipped(160)))" }
                let weekNotes = goal.notes.filter { $0.date >= start && $0.date < end }
                if weekNotes.isEmpty {
                    line += "\n  (no notes this week)"
                } else {
                    for note in weekNotes.suffix(8) {
                        line += "\n  - \(PromptLibrary.formatted(note.date, template: "EEE")): \(note.text.clipped(200))"
                    }
                }
                return line
            }.joined(separator: "\n")
        }
        let checkIns = db.prompts(since: start, limit: 300).filter { p in
            (p.kind == .question || p.kind == .nudge) && p.status == .answered
        }
        let openLoops = db.insights(statuses: [.open], kinds: [.task, .commitment, .event], since: nil, limit: 60)
        let openLoopsText = openLoops.isEmpty
            ? "(none)"
            : openLoops.map { PromptLibrary.itemLine($0) }.joined(separator: "\n")
        let dailyText = dailies.isEmpty
            ? "(no daily digests this week)"
            : dailies.map { "### \($0.day)\n\($0.markdown.clipped(6_000))" }.joined(separator: "\n\n")

        let user = """
        <week>\(rangeLabel)</week>
        <now>\(PromptLibrary.nowLine(now))</now>

        <profile>
        \(SettingsStore.current.profileBlock)
        </profile>

        <goals>
        \(goalLines)
        </goals>

        <captured_this_week>
        \(DigestEngine.groupedItems(captured))
        </captured_this_week>

        <open_loops>
        \(openLoopsText)
        </open_loops>

        <check_ins_answered>
        \(DigestEngine.checkInLines(checkIns))
        </check_ins_answered>

        <daily_digests>
        \(dailyText)
        </daily_digests>

        Write the weekly review now.
        """

        let markdown = try await llm.complete(system: PromptLibrary.weeklyReviewSystem, user: user,
                                              tier: .foreground, maxTokens: 12_000).trimmed
        guard !markdown.isEmpty else { throw DigestEngineError.emptyReply }

        let digest = Digest(day: "week-\(day.dayKey)", markdown: markdown, createdAt: Date())
        db.upsertDigest(digest)
        EarshotEvents.post(.digests)

        var brief = PromptLibrary.digestBrief(markdown, sentences: 2)
        if brief.isEmpty { brief = "Your weekly review is ready on your Mac." }
        releaseDigestPrompt(title: "Your week in review", body: brief, relatedID: digest.day,
                            rationale: "Weekly review for \(rangeLabel).")
        Log.info("DigestEngine: weekly review \(digest.day) stored.")
        return digest
    }

    // MARK: Schedule

    func runScheduledIfNeeded() async {
        let started: Bool = locked {
            if scheduledRunning { return false }
            scheduledRunning = true
            return true
        }
        guard started else { return }
        defer { locked { scheduledRunning = false } }

        guard llm.isConfigured else { return }
        let settings = SettingsStore.current
        let now = Date()
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let todayKey = now.dayKey
        let lastDaily = db.kvGet(DigestEngine.dailyLastRunKey) ?? ""

        // Catch up on yesterday when the Mac was asleep or off at digest time.
        if hour < settings.dailyDigestHour, let yesterday = cal.date(byAdding: .day, value: -1, to: now) {
            let key = yesterday.dayKey
            if lastDaily < key, db.digest(day: key) == nil, mayAttempt(key, now: now),
               db.wordCount(from: yesterday.startOfDay, to: yesterday.endOfDay) > DigestEngine.minimumWords {
                await runDaily(for: yesterday, key: key, now: now)
            }
        }

        if hour >= settings.dailyDigestHour, lastDaily != todayKey, mayAttempt(todayKey, now: now),
           db.wordCount(from: now.startOfDay, to: now) > DigestEngine.minimumWords {
            await runDaily(for: now, key: todayKey, now: now)
        }

        // The weekly review, or a catch-up for the latest one missed while the Mac was asleep or off.
        if let reviewDay = DigestEngine.latestWeeklyReviewDay(now: now, settings: settings, calendar: cal) {
            let reviewKey = reviewDay.dayKey
            let weeklyKey = "week-\(reviewKey)"
            let isToday = reviewKey == todayKey
            let lastWeekly = db.kvGet(DigestEngine.weeklyLastRunKey) ?? ""
            if lastWeekly < reviewKey, isToday || db.digest(day: weeklyKey) == nil, mayAttempt(weeklyKey, now: now) {
                let weekStart = cal.date(byAdding: .day, value: -6, to: reviewDay) ?? reviewDay.addingTimeInterval(-6 * 86_400)
                let weekEnd = min(reviewDay.endOfDay, now)
                if db.wordCount(from: weekStart, to: weekEnd) > DigestEngine.minimumWords {
                    if !isToday { Log.info("DigestEngine: catching up on the weekly review ending \(reviewKey).") }
                    do {
                        _ = try await generateWeekly(endingOn: isToday ? now : reviewDay)
                        let current = db.kvGet(DigestEngine.weeklyLastRunKey) ?? ""
                        if reviewKey > current { db.kvSet(DigestEngine.weeklyLastRunKey, reviewKey) }
                        clearFailure(weeklyKey)
                    } catch {
                        noteFailure(weeklyKey, now: now)
                        Log.error("DigestEngine: weekly review ending \(reviewKey) failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// The latest day, not after `now`, on which a weekly review was due: the review weekday once
    /// the digest hour has passed (today only after that hour). Nil for an invalid weekday setting.
    private static func latestWeeklyReviewDay(now: Date, settings: AppSettings, calendar cal: Calendar) -> Date? {
        let today = cal.startOfDay(for: now)
        let hour = cal.component(.hour, from: now)
        for offset in 0...7 {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            guard cal.component(.weekday, from: day) == settings.weeklyReviewWeekday else { continue }
            if offset == 0 && hour < settings.dailyDigestHour { continue }
            return cal.startOfDay(for: day)
        }
        return nil
    }

    private func runDaily(for day: Date, key: String, now: Date) async {
        do {
            _ = try await generateDaily(for: day)
            // Never move the marker backwards (yesterday's catch-up after today's digest).
            let current = db.kvGet(DigestEngine.dailyLastRunKey) ?? ""
            if key > current { db.kvSet(DigestEngine.dailyLastRunKey, key) }
            clearFailure(key)
        } catch {
            noteFailure(key, now: now)
            Log.error("DigestEngine: daily digest for \(key) failed: \(error.localizedDescription)")
        }
    }

    private func mayAttempt(_ key: String, now: Date) -> Bool {
        locked {
            guard let last = failedAttempts[key] else { return true }
            return now.timeIntervalSince(last) >= DigestEngine.retryInterval
        }
    }

    private func noteFailure(_ key: String, now: Date) {
        locked { failedAttempts[key] = now }
    }

    private func clearFailure(_ key: String) {
        locked { _ = failedAttempts.removeValue(forKey: key) }
    }

    // MARK: Long days

    /// Condenses a long day chunk by chunk (≤ 3 at a time). Failed chunks are marked, not fatal,
    /// unless every chunk failed.
    private func condenseInChunks(_ utterances: [Utterance], bookmarks: [StoredBookmark], now: Date) async throws -> String {
        var chunks: [[Utterance]] = []
        var current: [Utterance] = []
        var words = 0
        for u in utterances {
            let w = PromptLibrary.wordCount(u.text)
            if words + w > DigestEngine.chunkWords && !current.isEmpty {
                chunks.append(current)
                current = []
                words = 0
            }
            current.append(u)
            words += w
        }
        if !current.isEmpty { chunks.append(current) }

        var inputs: [String] = []
        var labels: [String] = []
        for (index, chunk) in chunks.enumerated() {
            let first = chunk.first?.startedAt ?? now
            let last = chunk.last?.endedAt ?? now
            let label = "\(first.timeText)–\(last.timeText)"
            labels.append(label)
            let marks = bookmarks.filter { $0.at >= first.addingTimeInterval(-120) && $0.at <= last.addingTimeInterval(60) }
            let input = """
            <part index="\(index + 1)" of="\(chunks.count)" span="\(label)">
            <bookmarks>
            \(DigestEngine.bookmarkLines(marks))
            </bookmarks>
            <transcript>
            \(PromptLibrary.transcriptBlock(chunk, now: now))
            </transcript>
            </part>

            Condense this part as instructed.
            """
            inputs.append(input)
        }

        let allInputs = inputs
        let total = allInputs.count
        let results: [Int: Result<String, Error>] = await withTaskGroup(of: ChunkOutcome.self,
                                                                         returning: [Int: Result<String, Error>].self) { group in
            var collected: [Int: Result<String, Error>] = [:]
            var nextIndex = 0
            while nextIndex < min(DigestEngine.maxConcurrentChunks, total) {
                let index = nextIndex
                let input = allInputs[index]
                group.addTask { await self.condenseChunk(index: index, input: input) }
                nextIndex += 1
            }
            while let finished = await group.next() {
                collected[finished.0] = finished.1
                if nextIndex < total {
                    let index = nextIndex
                    let input = allInputs[index]
                    group.addTask { await self.condenseChunk(index: index, input: input) }
                    nextIndex += 1
                }
            }
            return collected
        }

        var sections: [String] = []
        var firstError: Error?
        var failures = 0
        for index in 0..<total {
            let header = "### Part \(index + 1) (\(labels[index]))"
            switch results[index] {
            case .success(let text)?:
                sections.append("\(header)\n\(text.trimmed)")
            case .failure(let error)?:
                failures += 1
                if firstError == nil { firstError = error }
                sections.append("\(header)\n(This part could not be condensed.)")
            case nil:
                failures += 1
                sections.append("\(header)\n(This part could not be condensed.)")
            }
        }
        if failures == total {
            throw firstError ?? (DigestEngineError.emptyReply as Error)
        }
        return sections.joined(separator: "\n\n")
    }

    private func condenseChunk(index: Int, input: String) async -> ChunkOutcome {
        do {
            let text = try await llm.complete(system: PromptLibrary.digestChunkSystem, user: input,
                                              tier: .background, maxTokens: 6_000)
            let result: Result<String, Error> = .success(text)
            return (index, result)
        } catch {
            Log.error("DigestEngine: condensing part \(index + 1) failed: \(error.localizedDescription)")
            let result: Result<String, Error> = .failure(error)
            return (index, result)
        }
    }

    // MARK: Watch prompt

    private func releaseDigestPrompt(title: String, body: String, relatedID: String, rationale: String) {
        // Replace an earlier, unread prompt for the same digest instead of stacking them.
        for var old in db.prompts(statuses: [.queued, .pending, .delivered], limit: 300) {
            guard old.kind == .digest, old.relatedID == relatedID else { continue }
            old.status = .expired
            db.upsertPrompt(old)
        }
        // Digests always come through, but during quiet hours (the default digest hour is also where
        // quiet hours start) they arrive silently: priority 1 is a passive notification on the watch.
        let quiet = SettingsStore.current.isQuietHour(Date())
        let prompt = StoredPrompt.make(kind: .digest, title: title, body: body.clipped(300), choices: [],
                                       allowsFreeText: false, allowsVoice: false, priority: quiet ? 1 : 2,
                                       status: .pending, rationale: rationale, relatedID: relatedID,
                                       expiresAt: Date().addingTimeInterval(18 * 3_600))
        db.upsertPrompt(prompt)
        EarshotEvents.post(.prompts)
    }

    // MARK: Formatting

    private func goalsWithTodaysNotes(_ goals: [Goal], from start: Date, to end: Date) -> String {
        guard !goals.isEmpty else { return "(no active goals yet)" }
        return goals.map { goal -> String in
            var line = "- \(goal.title)"
            if let why = goal.why.nilIfEmpty { line += " (why: \(why.clipped(160)))" }
            let notes = goal.notes.filter { $0.date >= start && $0.date < end }
            if notes.isEmpty {
                if let last = goal.notes.last { line += "; last note \(last.date.shortText): \(last.text.clipped(140))" }
            } else {
                for note in notes.suffix(6) { line += "\n  - today: \(note.text.clipped(200))" }
            }
            return line
        }.joined(separator: "\n")
    }

    private static func groupedItems(_ items: [Insight]) -> String {
        guard !items.isEmpty else { return "(nothing captured)" }
        var sections: [String] = []
        for kind in InsightKind.allCases {
            let ofKind = items.filter { $0.kind == kind }
            guard !ofKind.isEmpty else { continue }
            let lines = ofKind.prefix(25).map { item -> String in
                var line = "- \(item.title)"
                if let due = item.dueAt { line += " (due \(due.shortText))" }
                if item.status == .done { line += " (done)" }
                if !item.people.isEmpty { line += " (with \(item.people.prefix(3).joined(separator: ", ")))" }
                return line
            }
            sections.append("\(kind.label):\n" + lines.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n")
    }

    private static func checkInLines(_ prompts: [StoredPrompt]) -> String {
        guard !prompts.isEmpty else { return "(none)" }
        return prompts.prefix(20).map { p in
            "- Q: \(p.title) → A: \((p.answerText ?? "").clipped(200))"
        }.joined(separator: "\n")
    }

    private static func bookmarkLines(_ bookmarks: [StoredBookmark]) -> String {
        guard !bookmarks.isEmpty else { return "(none)" }
        return bookmarks.map { b -> String in
            if let note = b.note?.nilIfEmpty { return "- \(b.at.timeText) (note: \(note.clipped(200)))" }
            return "- \(b.at.timeText)"
        }.joined(separator: "\n")
    }

    private static func eventLines(_ events: [CalendarEventSummary]) -> String {
        guard !events.isEmpty else { return "(nothing scheduled, or calendar access not granted)" }
        return events.prefix(20).map { e -> String in
            let allDay = e.end.timeIntervalSince(e.start) >= 23 * 3_600
            var line = allDay ? "- All day: \(e.title)" : "- \(e.start.timeText)–\(e.end.timeText) \(e.title)"
            if let location = e.location?.nilIfEmpty { line += " (\(location))" }
            return line
        }.joined(separator: "\n")
    }
}
