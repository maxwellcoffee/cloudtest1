//  MemoryChat.swift
//  "Ask your day": answers questions from the transcript archive with
//  keyword + time-range retrieval and cited sources.

import Foundation

private enum MemoryChatError: LocalizedError {
    case emptyQuestion
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .emptyQuestion:
            return "Ask a question first."
        case .notConfigured:
            return "AI is not configured. Add an Anthropic API key in Settings → AI."
        }
    }
}

private struct MemorySearchPlan {
    var keywords: [String]
    var start: Date?
    var end: Date?
}

private struct RetrievedMemory {
    var utterances: [Utterance]   // chronological, unique ids
    var digests: [Digest]
    var insights: [Insight]
}

final class MemoryChat: @unchecked Sendable {
    private let db: Database
    private let llm: LLMService

    private static let keywordLimit = 40
    private static let rangeLimit = 400
    private static let maxExcerptLines = 450
    private static let maxExcerptCharacters = 60_000
    private static let maxCitations = 8

    private static let stopWords: Set<String> = [
        "a", "an", "the", "and", "or", "not", "to", "of", "in", "on", "at", "for", "with", "by", "from", "about",
        "is", "are", "was", "were", "be", "been", "do", "did", "does", "done", "have", "has", "had",
        "i", "me", "my", "mine", "we", "us", "our", "you", "your", "he", "she", "they", "them", "it", "its",
        "what", "when", "where", "who", "whom", "why", "how", "which", "that", "this", "these", "those",
        "say", "said", "tell", "told", "talk", "talked", "mention", "mentioned", "remind", "remember",
        "can", "could", "would", "should", "will", "any", "some", "there", "then", "than", "so", "if",
        "near", "today", "yesterday", "tomorrow", "week", "last", "ago", "earlier", "morning", "afternoon", "evening",
    ]

    init(db: Database, llm: LLMService) {
        self.db = db
        self.llm = llm
    }

    // MARK: Ask

    func ask(_ question: String, persist: Bool) async throws -> ChatMessage {
        let trimmedQuestion = question.trimmed
        guard !trimmedQuestion.isEmpty else { throw MemoryChatError.emptyQuestion }
        guard llm.isConfigured else { throw MemoryChatError.notConfigured }

        let userMessage = ChatMessage.make(role: .user, text: trimmedQuestion)
        let now = Date()
        // Earlier turns help with follow-ups ("and the day before?"); only for the Mac chat history.
        let history = persist ? db.chatMessages(limit: 6) : []

        let plan = await planSearch(trimmedQuestion, history: history, now: now)
        let memory = retrieve(plan, now: now)
        Log.info("MemoryChat: \(plan.keywords.count) keywords, \(memory.utterances.count) excerpts, \(memory.digests.count) digests, \(memory.insights.count) insights.")
        let reply = try await answer(trimmedQuestion, plan: plan, memory: memory, history: history, now: now)

        if persist {
            db.insertChatMessage(userMessage)
            db.insertChatMessage(reply)
            EarshotEvents.post(.chat)
        }
        return reply
    }

    // MARK: Step 1 – plan the search

    private func planSearch(_ question: String, history: [ChatMessage], now: Date) async -> MemorySearchPlan {
        let user = """
        <now>\(PromptLibrary.nowLine(now))</now>

        <earlier_conversation>
        \(MemoryChat.historyText(history))
        </earlier_conversation>

        <question>\(question.clipped(2_000))</question>

        Plan the search and return the JSON.
        """
        do {
            let reply = try await llm.completeJSON(system: PromptLibrary.memoryQuerySystem, user: user,
                                                   schema: PromptLibrary.memoryQuerySchema,
                                                   tier: .background, maxTokens: 4_000)
            var keywords: [String] = []
            for raw in PromptLibrary.strings(reply["keywords"]) {
                let cleaned = MemoryChat.sanitize(raw)
                if !cleaned.isEmpty && !keywords.contains(cleaned) { keywords.append(cleaned) }
            }
            if keywords.isEmpty { keywords = MemoryChat.fallbackKeywords(question) }

            let startRaw = PromptLibrary.text(reply["start_iso"])
            let endRaw = PromptLibrary.text(reply["end_iso"])
            var start = DateParsing.parse(startRaw)
            var end = DateParsing.parse(endRaw)
            if let e = end, DateParsing.isDateOnly(endRaw) { end = e.endOfDay }
            if start != nil && end == nil { end = now }
            if let e = end, start == nil { start = e.addingTimeInterval(-86_400) }
            if let s = start, let e = end, e < s {
                start = e
                end = s
            }
            return MemorySearchPlan(keywords: Array(keywords.prefix(8)), start: start, end: end)
        } catch {
            Log.error("MemoryChat: search planning failed (\(error.localizedDescription)); using plain keywords.")
            return MemorySearchPlan(keywords: MemoryChat.fallbackKeywords(question), start: nil, end: nil)
        }
    }

    // MARK: Step 2 – retrieve

    private func retrieve(_ plan: MemorySearchPlan, now: Date) -> RetrievedMemory {
        var byID: [Int64: Utterance] = [:]
        var order: [Int64] = []   // importance order: keyword hits, their context, then the time range
        func add(_ items: [Utterance]) {
            for u in items where byID[u.id] == nil && !u.text.trimmed.isEmpty {
                byID[u.id] = u
                order.append(u.id)
            }
        }

        // Keyword hits (FTS joins terms with AND, so widen with single-term searches when sparse).
        var hits: [Utterance] = []
        if !plan.keywords.isEmpty {
            hits = db.searchUtterances(plan.keywords.joined(separator: " "), limit: MemoryChat.keywordLimit)
            if hits.count < 10 {
                var seen = Set(hits.map { $0.id })
                for term in plan.keywords.prefix(6) {
                    for u in db.searchUtterances(term, limit: 12) where !seen.contains(u.id) {
                        seen.insert(u.id)
                        hits.append(u)
                    }
                }
            }
        }
        if let start = plan.start, let end = plan.end {
            let inRange = hits.filter { $0.startedAt >= start && $0.startedAt <= end }
            let outside = hits.filter { $0.startedAt < start || $0.startedAt > end }
            hits = inRange + Array(outside.prefix(10))
        }
        add(hits)

        // A little context around the strongest hits.
        for hit in hits.prefix(8) {
            add(db.utterances(from: hit.startedAt.addingTimeInterval(-45), to: hit.endedAt.addingTimeInterval(45), limit: 12))
        }

        // The time range, sampled in slices so a long range is not just its first minutes.
        if let start = plan.start, let end = plan.end {
            let span = end.timeIntervalSince(start)
            var slices = 0
            if span > 0 && span <= 36 * 3_600 {
                slices = min(12, max(1, Int((span / 7_200).rounded(.up))))
            } else if span > 36 * 3_600 && span <= 14 * 86_400 {
                slices = min(14, max(1, Int((span / 86_400).rounded(.up))))
            }
            if slices > 0 {
                let perSlice = max(20, MemoryChat.rangeLimit / slices)
                let sliceLength = span / Double(slices)
                for index in 0..<slices {
                    let sliceStart = start.addingTimeInterval(Double(index) * sliceLength)
                    let sliceEnd = index == slices - 1 ? end : sliceStart.addingTimeInterval(sliceLength)
                    add(db.utterances(from: sliceStart, to: sliceEnd, limit: perSlice))
                }
            }
        }

        // Keep the most important lines within budget, then present them chronologically.
        var kept: [Utterance] = []
        var characters = 0
        for id in order {
            guard let u = byID[id] else { continue }
            let length = min(u.text.count, 600) + 30
            if kept.count >= MemoryChat.maxExcerptLines || characters + length > MemoryChat.maxExcerptCharacters { break }
            kept.append(u)
            characters += length
        }
        kept.sort { $0.startedAt < $1.startedAt }

        // Digests: days in the range, plus the most recent ones.
        var digests: [Digest] = []
        var digestDays = Set<String>()
        if let start = plan.start, let end = plan.end, end.timeIntervalSince(start) <= 31 * 86_400 {
            var day = start.startOfDay
            while day < end && digests.count < 7 {
                if let digest = db.digest(day: day.dayKey) {
                    digests.append(digest)
                    digestDays.insert(digest.day)
                }
                day = day.endOfDay
            }
        }
        for digest in db.digests(limit: 3) where !digestDays.contains(digest.day) {
            digests.append(digest)
            digestDays.insert(digest.day)
        }

        // Insights mentioning the keywords, plus those from the time range.
        let since = (plan.start ?? now.addingTimeInterval(-30 * 86_400)).addingTimeInterval(-86_400)
        let pool = db.insights(statuses: nil, kinds: nil, since: since, limit: 400)
        let terms = plan.keywords.flatMap { $0.split(separator: " ").map(String.init) }.filter { $0.count >= 3 }
        var insights: [Insight] = []
        var insightIDs = Set<String>()
        for insight in pool {
            let haystack = (insight.title + " " + insight.detail + " " + insight.people.joined(separator: " ")).lowercased()
            if terms.contains(where: { haystack.contains($0) }) {
                insights.append(insight)
                insightIDs.insert(insight.id)
            }
        }
        if let start = plan.start, let end = plan.end {
            for insight in pool where !insightIDs.contains(insight.id) {
                let at = insight.sourceFrom ?? insight.createdAt
                if at >= start && at <= end {
                    insights.append(insight)
                    insightIDs.insert(insight.id)
                }
            }
        }
        return RetrievedMemory(utterances: kept, digests: digests, insights: Array(insights.prefix(40)))
    }

    // MARK: Step 3 – answer with citations

    private func answer(_ question: String, plan: MemorySearchPlan, memory: RetrievedMemory,
                        history: [ChatMessage], now: Date) async throws -> ChatMessage {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d h:mm a")

        let excerpts: String
        if memory.utterances.isEmpty {
            excerpts = "(no transcript lines matched the search)"
        } else {
            excerpts = memory.utterances.map { u -> String in
                var line = "#\(u.id) [\(formatter.string(from: u.startedAt))] "
                if let speaker = u.speaker?.nilIfEmpty { line += "(\(speaker)) " }
                return line + u.text.trimmed.clipped(600)
            }.joined(separator: "\n")
        }
        let digests = memory.digests.isEmpty
            ? "(none)"
            : memory.digests.map { "### \($0.day)\n\($0.markdown.clipped(4_000))" }.joined(separator: "\n\n")
        let insights = memory.insights.isEmpty
            ? "(none)"
            : memory.insights.map { i -> String in
                var line = PromptLibrary.itemLine(i)
                line += " captured \((i.sourceFrom ?? i.createdAt).shortText)"
                if let detail = i.detail.nilIfEmpty { line += ": \(detail.clipped(240))" }
                return line
            }.joined(separator: "\n")
        let openTasks = db.insights(statuses: [.open], kinds: [.task, .commitment, .event], since: nil, limit: 30)
        let openText = openTasks.isEmpty ? "(none)" : openTasks.map { PromptLibrary.itemLine($0) }.joined(separator: "\n")
        var searchLine = "keywords: " + (plan.keywords.isEmpty ? "(none)" : plan.keywords.joined(separator: ", "))
        if let start = plan.start, let end = plan.end {
            searchLine += "; time range: \(start.shortText) to \(end.shortText)"
        }

        let user = """
        <now>\(PromptLibrary.nowLine(now))</now>

        <profile>
        \(SettingsStore.current.profileBlock)
        </profile>

        <earlier_conversation>
        \(MemoryChat.historyText(history))
        </earlier_conversation>

        <question>\(question.clipped(2_000))</question>

        <search>\(searchLine)</search>

        <transcript_excerpts>
        \(excerpts)
        </transcript_excerpts>

        <daily_digests>
        \(digests)
        </daily_digests>

        <captured_insights>
        \(insights)
        </captured_insights>

        <goals>
        \(PromptLibrary.goalsBlock(db.goals(statuses: [.active])))
        </goals>

        <open_tasks>
        \(openText)
        </open_tasks>

        Answer the question as instructed and return the JSON.
        """

        let reply = try await llm.completeJSON(system: PromptLibrary.memoryAnswerSystem, user: user,
                                               schema: PromptLibrary.memoryAnswerSchema,
                                               tier: .foreground, maxTokens: 8_000)

        var text = PromptLibrary.text(reply["answer"])
        if text.isEmpty {
            text = memory.utterances.isEmpty
                ? "I couldn't find anything about that in what I've heard so far."
                : "I found some related moments but couldn't put together a reliable answer."
        }

        let byID = Dictionary(memory.utterances.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var citations: [Citation] = []
        var used = Set<Int64>()
        for raw in reply["citations"]?.arrayValue ?? [] {
            let rawID = PromptLibrary.text(raw["utterance_id"]).replacingOccurrences(of: "#", with: "")
            guard let id = Int64(rawID), let u = byID[id], !used.contains(id) else { continue }
            used.insert(id)
            let quote = PromptLibrary.text(raw["quote"]).nilIfEmpty ?? u.text.trimmed
            citations.append(Citation(utteranceID: id, at: u.startedAt, quote: quote.clipped(200)))
            if citations.count >= MemoryChat.maxCitations { break }
        }
        return ChatMessage.make(role: .assistant, text: text, citations: citations)
    }

    // MARK: Search (agent tool)

    func search(_ query: String, days: Int, limit: Int) -> [Utterance] {
        let cleaned = MemoryChat.sanitize(query)
        guard !cleaned.isEmpty else { return [] }
        let cap = max(1, limit)
        let cutoff: Date? = days > 0 ? Date().addingTimeInterval(-Double(days) * 86_400) : nil
        func recent(_ items: [Utterance]) -> [Utterance] {
            guard let cutoff else { return items }
            return items.filter { $0.startedAt >= cutoff }
        }
        var results = recent(db.searchUtterances(cleaned, limit: cap * 4 + 20))
        if results.count < cap {
            let terms = cleaned.split(separator: " ").map(String.init).filter { $0.count >= 3 && !MemoryChat.stopWords.contains($0) }
            if terms.count > 1 {
                var seen = Set(results.map { $0.id })
                for term in terms.prefix(6) {
                    for u in recent(db.searchUtterances(term, limit: cap * 2 + 10)) where !seen.contains(u.id) {
                        seen.insert(u.id)
                        results.append(u)
                    }
                }
            }
        }
        return Array(results.prefix(cap))
    }

    // MARK: Helpers

    /// Lowercased words without punctuation, safe for the full-text index (no FTS operators).
    private static func sanitize(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            scalars.append(CharacterSet.alphanumerics.contains(scalar) ? scalar : " ")
        }
        return String(scalars).lowercased()
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 2 }
            .joined(separator: " ")
    }

    /// Distinctive words of the question when the planner is unavailable.
    private static func fallbackKeywords(_ question: String) -> [String] {
        var keywords: [String] = []
        let words = sanitize(question).split(separator: " ").map(String.init)
        for word in words {
            guard word.count >= 3, !stopWords.contains(word), !keywords.contains(word) else { continue }
            keywords.append(word)
        }
        return Array(keywords.prefix(6))
    }

    private static func historyText(_ history: [ChatMessage]) -> String {
        guard !history.isEmpty else { return "(none)" }
        return history.suffix(4).map { message -> String in
            let who = message.role == .user ? "User" : "Earshot"
            return "\(who): \(message.text.clipped(600))"
        }.joined(separator: "\n")
    }
}
