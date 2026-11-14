//  MCPHandler.swift
//  Personal-memory Model Context Protocol server (feature #91).
//
//  Transport: MCP "Streamable HTTP" on the single endpoint POST /mcp, answered
//  with plain JSON (Content-Type: application/json, never an SSE stream).
//  - A POST body is one JSON-RPC 2.0 message, or a JSON array batch (answered
//    with an array). Bodies holding only notifications or client responses get
//    202 Accepted with an empty body.
//  - GET (and every other method) gets 405: this server offers no SSE stream.
//  - Auth: "Authorization: Bearer <token>", compared in constant time. The token
//    (32 random bytes, hex) lives in the Keychain under account "mcp-token".
//  - `initialize` answers with a random Mcp-Session-Id header. The server keeps no
//    per-session state, so later requests are accepted with or without it.
//  - Origin validation (DNS-rebinding protection) is done by `APIRouter`.
//
//  Tools are read-only: search_memory, get_transcript, list_open_loops,
//  list_goals, get_digest, ask_memory. Results are compact text with local
//  times and ids, capped at about 20,000 characters.

import Foundation
import Security

// MARK: - Private types

/// A JSON-RPC error object: {"code": …, "message": …}.
private struct MCPRPCError: Error {
    let code: Int
    let message: String

    static func invalidRequest(_ detail: String) -> MCPRPCError {
        MCPRPCError(code: -32600, message: "Invalid Request: \(detail)")
    }

    static func methodNotFound(_ method: String) -> MCPRPCError {
        MCPRPCError(code: -32601, message: "Method not found: \(method)")
    }

    static func invalidParams(_ detail: String) -> MCPRPCError {
        MCPRPCError(code: -32602, message: "Invalid params: \(detail)")
    }
}

/// A problem inside a tool; reported as a tool result with isError: true.
private struct MCPToolFailure: Error {
    let message: String
}

/// What one JSON-RPC message produced.
private struct MCPOutcome {
    /// nil for notifications and for responses sent by the client.
    var response: JSONValue?
    /// True when the message was a successful `initialize`.
    var startedSession: Bool = false
}

/// Typed access to a tools/call `arguments` object.
private struct MCPArguments {
    let values: [String: JSONValue]

    /// Trimmed, non-empty string (numbers are accepted and converted).
    func string(_ key: String) -> String? {
        guard let value = values[key] else { return nil }
        switch value {
        case .string(let text):
            return text.nilIfEmpty
        case .number(let number):
            guard number.isFinite else { return nil }
            if number.rounded() == number && abs(number) < 1e15 { return String(Int64(number)) }
            return String(number)
        default:
            return nil
        }
    }

    /// Integer argument; nil when absent. Throws for values of the wrong type.
    func int(_ key: String) throws -> Int? {
        guard let value = values[key] else { return nil }
        switch value {
        case .null:
            return nil
        case .number(let number):
            guard number.isFinite, abs(number) < 1e9 else {
                throw MCPToolFailure(message: "“\(key)” is out of range.")
            }
            return Int(number.rounded())
        case .string(let text):
            let cleaned = text.trimmed
            if cleaned.isEmpty { return nil }
            guard let parsed = Int(cleaned), abs(parsed) < 1_000_000_000 else {
                throw MCPToolFailure(message: "“\(key)” must be a whole number.")
            }
            return parsed
        default:
            throw MCPToolFailure(message: "“\(key)” must be a whole number.")
        }
    }
}

/// Formatters for one tool call (en_US_POSIX patterns, local time zone).
private struct MCPClock {
    private let stampFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    private let dateFormatter: DateFormatter
    private let dayFormatter: DateFormatter
    private let keyFormatter: DateFormatter
    private let hourMinuteFormatter: DateFormatter

    init() {
        func make(_ format: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            return formatter
        }
        stampFormatter = make("EEE yyyy-MM-dd h:mm a")
        timeFormatter = make("h:mm a")
        dateFormatter = make("EEE yyyy-MM-dd")
        dayFormatter = make("EEEE, MMMM d, yyyy")
        keyFormatter = make("yyyy-MM-dd")
        hourMinuteFormatter = make("HH:mm")
    }

    /// "Sat 2026-11-14 3:42 PM"
    func stamp(_ date: Date) -> String { stampFormatter.string(from: date) }
    /// "3:42 PM"
    func time(_ date: Date) -> String { timeFormatter.string(from: date) }
    /// "Sat 2026-11-14"
    func date(_ date: Date) -> String { dateFormatter.string(from: date) }
    /// "Saturday, November 14, 2026"
    func day(_ date: Date) -> String { dayFormatter.string(from: date) }
    /// "2026-11-14"
    func key(_ date: Date) -> String { keyFormatter.string(from: date) }
    /// "15:42"
    func hourMinute(_ date: Date) -> String { hourMinuteFormatter.string(from: date) }

    var zoneNote: String { "Times are local (\(TimeZone.current.identifier))." }
}

/// The read-only tools this server exposes.
private enum MCPTool: String, CaseIterable {
    case searchMemory = "search_memory"
    case getTranscript = "get_transcript"
    case listOpenLoops = "list_open_loops"
    case listGoals = "list_goals"
    case getDigest = "get_digest"
    case askMemory = "ask_memory"

    var title: String {
        switch self {
        case .searchMemory: return "Search memory"
        case .getTranscript: return "Get transcript"
        case .listOpenLoops: return "List open loops"
        case .listGoals: return "List goals"
        case .getDigest: return "Get digest"
        case .askMemory: return "Ask memory"
        }
    }

    var summary: String {
        switch self {
        case .searchMemory:
            return "Keyword search over everything the user said and heard (always-on transcripts recorded by their Apple Watch or Mac). Returns matching transcript lines, best match first, with local times and utterance ids, plus related captured items (tasks, commitments, facts, decisions). Use specific words: names, places, topics, phrases."
        case .getTranscript:
            return "Returns the transcript of one local day, optionally limited to a time window, including the user's bookmarks. Use it to read the context around a search hit. Long results are truncated; the output says how to continue with start_time."
        case .listOpenLoops:
            return "Lists the open tasks, commitments (promises the user made and promises made to them) and open questions Earshot captured from conversations, with due dates, people and ids."
        case .listGoals:
            return "Lists the user's goals (active, paused and completed) with why they matter and recent progress notes."
        case .getDigest:
            return "Returns an AI-written daily digest (summary, highlights, commitments, open loops, reflections) or weekly review, as Markdown. Omit date for the most recent one."
        case .askMemory:
            return "Asks Earshot's memory assistant a natural-language question. It searches the archive itself and answers with cited transcript lines. Slower than search_memory because it calls an AI model; use it for questions that need synthesis across many moments."
        }
    }

    var inputSchema: JSONValue {
        switch self {
        case .searchMemory:
            return Schema.object([
                ("query", Schema.string("Words to look for, e.g. a name, place, topic or phrase.")),
                ("days", Schema.integer("Only search the last N days. Omit or 0 to search the whole archive.").setting("minimum", 0)),
            ], required: ["query"])
        case .getTranscript:
            return Schema.object([
                ("date", Schema.string("Local day as yyyy-MM-dd, or \"today\" / \"yesterday\".")),
                ("start_time", Schema.string("Optional local start time in 24-hour HH:mm (e.g. \"14:30\"; \"2:30 PM\" also works). Default: start of the day.")),
                ("end_time", Schema.string("Optional local end time in 24-hour HH:mm (\"24:00\" = midnight). Default: end of the day.")),
            ], required: ["date"])
        case .listOpenLoops, .listGoals:
            return Schema.object([], required: [])
        case .getDigest:
            return Schema.object([
                ("date", Schema.string("Optional local day as yyyy-MM-dd, \"today\" or \"yesterday\"; or \"week-yyyy-MM-dd\" for the weekly review ending that day. Omit for the most recent digest.")),
            ], required: [])
        case .askMemory:
            return Schema.object([
                ("question", Schema.string("The question, in natural language, e.g. \"What did Sam say about the launch date?\"")),
            ], required: ["question"])
        }
    }

    var definition: JSONValue {
        .object([
            "name": .string(rawValue),
            "title": .string(title),
            "description": .string(summary),
            "inputSchema": inputSchema,
            "annotations": .object([
                "title": .string(title),
                "readOnlyHint": true,
                "openWorldHint": false,
            ]),
        ])
    }
}

// MARK: - Handler

final class MCPHandler: @unchecked Sendable {
    private static let tokenAccount = "mcp-token"
    /// Protocol versions this server speaks (initialize echoes one of these).
    private static let supportedVersions: Set<String> = ["2025-11-25", "2025-06-18", "2025-03-26"]
    private static let defaultVersion = "2025-06-18"
    private static let serverName = "earshot-memory"
    private static let serverVersion = "1.0"
    private static let maxOutputCharacters = 20_000
    private static let maxBatchSize = 50
    private static let maxToolCallsPerMinute = 120
    private static let searchLimit = 40
    private static let transcriptRowLimit = 5_000

    private let db: Database
    private let memory: MemoryChat
    private let lock = NSLock()
    /// Guarded by `lock`.
    private var cachedToken: String?
    /// Guarded by `lock`. Start times of recent tools/call requests (rate limit).
    private var recentToolCalls: [Date] = []

    init(db: Database, memory: MemoryChat) {
        self.db = db
        self.memory = memory
    }

    // MARK: Token

    /// Bearer token MCP clients must send; created on first use, stored in the Keychain.
    var token: String {
        lock.lock()
        defer { lock.unlock() }
        return currentTokenLocked()
    }

    func rotateToken() {
        let fresh = MCPHandler.randomHex(byteCount: 32)
        lock.lock()
        Keychain.set(fresh, for: MCPHandler.tokenAccount)
        if Keychain.get(MCPHandler.tokenAccount) != fresh {
            Log.error("MCP: could not save the new access token in the Keychain; it is valid until Earshot quits.")
        }
        cachedToken = fresh
        lock.unlock()
        Log.info("MCP: access token rotated; clients must use the new token")
    }

    /// Call with `lock` held.
    private func currentTokenLocked() -> String {
        if let existing = cachedToken { return existing }
        if let stored = Keychain.get(MCPHandler.tokenAccount)?.trimmed, MCPHandler.isWellFormedToken(stored) {
            cachedToken = stored
            return stored
        }
        let fresh = MCPHandler.randomHex(byteCount: 32)
        Keychain.set(fresh, for: MCPHandler.tokenAccount)
        if Keychain.get(MCPHandler.tokenAccount) != fresh {
            Log.error("MCP: could not save the access token in the Keychain; it will change when Earshot restarts.")
        }
        cachedToken = fresh
        return fresh
    }

    private func isAuthorized(_ authorizationHeader: String?) -> Bool {
        guard let header = authorizationHeader?.trimmed, !header.isEmpty else { return false }
        let parts = header.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2, parts[0].lowercased() == "bearer" else { return false }
        let presented = parts[1].trimmingCharacters(in: .whitespaces)
        guard !presented.isEmpty, presented.count <= 256 else { return false }
        return MCPHandler.constantTimeEquals(presented, token)
    }

    // MARK: HTTP entry point

    /// Handles POST /mcp (JSON-RPC 2.0: initialize, notifications/initialized, ping, tools/list, tools/call).
    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        guard request.method.uppercased() == "POST" else {
            var response = HTTPResponse.error(405, "The Earshot MCP endpoint accepts JSON-RPC messages via POST only; it offers no SSE stream.")
            response.headers["Allow"] = "POST"
            return response
        }
        guard isAuthorized(request.header(EarshotAPI.Header.authorization)) else {
            var response = HTTPResponse.error(401, "Missing or wrong MCP token. Copy it from Earshot → Settings → Integrations and send it as “Authorization: Bearer <token>”.")
            response.headers["WWW-Authenticate"] = "Bearer realm=\"\(MCPHandler.serverName)\""
            return response
        }

        let parsed: JSONValue
        do {
            parsed = try JSONValue.parse(request.body)
        } catch {
            let failure = MCPRPCError(code: -32700, message: "Parse error: the request body is not valid JSON.")
            return MCPHandler.reply(MCPHandler.errorMessage(id: .null, failure), status: 400)
        }

        let messages: [JSONValue]
        let isBatch: Bool
        switch parsed {
        case .array(let list):
            messages = list
            isBatch = true
        case .object:
            messages = [parsed]
            isBatch = false
        default:
            let failure = MCPRPCError.invalidRequest("expected a JSON-RPC message object or an array of them.")
            return MCPHandler.reply(MCPHandler.errorMessage(id: .null, failure), status: 400)
        }
        guard !messages.isEmpty else {
            let failure = MCPRPCError.invalidRequest("the batch is empty.")
            return MCPHandler.reply(MCPHandler.errorMessage(id: .null, failure), status: 400)
        }
        guard messages.count <= MCPHandler.maxBatchSize else {
            let failure = MCPRPCError.invalidRequest("a batch may hold at most \(MCPHandler.maxBatchSize) messages.")
            return MCPHandler.reply(MCPHandler.errorMessage(id: .null, failure), status: 400)
        }

        // MCP-Protocol-Version is sent on every request after initialization.
        let initializing = messages.contains { $0["method"]?.stringValue == "initialize" }
        if !initializing, let version = request.header("MCP-Protocol-Version")?.trimmed, !version.isEmpty,
           !MCPHandler.supportedVersions.contains(version) {
            let supported = MCPHandler.supportedVersions.sorted().joined(separator: ", ")
            let failure = MCPRPCError.invalidRequest("unsupported MCP-Protocol-Version “\(version)”. Supported: \(supported).")
            return MCPHandler.reply(MCPHandler.errorMessage(id: .null, failure), status: 400)
        }

        var responses: [JSONValue] = []
        var startedSession = false
        for message in messages {
            let outcome = await process(message)
            if let response = outcome.response { responses.append(response) }
            if outcome.startedSession { startedSession = true }
        }

        guard !responses.isEmpty else {
            // Only notifications / client responses: accepted, no body.
            return HTTPResponse(status: 202, headers: ["Cache-Control": "no-store"], body: Data())
        }
        let sessionID: String? = startedSession ? MCPHandler.randomHex(byteCount: 16) : nil
        if isBatch {
            return MCPHandler.reply(.array(responses), status: 200, sessionID: sessionID)
        }
        let single = responses[0]
        let unanswerable = single["error"] != nil && (single["id"]?.isNull ?? true)
        return MCPHandler.reply(single, status: unanswerable ? 400 : 200, sessionID: sessionID)
    }

    // MARK: JSON-RPC

    private func process(_ message: JSONValue) async -> MCPOutcome {
        guard case .object(let fields) = message else {
            let failure = MCPRPCError.invalidRequest("each message must be a JSON object.")
            return MCPOutcome(response: MCPHandler.errorMessage(id: .null, failure))
        }
        let rawID = fields["id"]
        guard fields["jsonrpc"]?.stringValue == "2.0" else {
            let failure = MCPRPCError.invalidRequest("“jsonrpc” must be \"2.0\".")
            return MCPOutcome(response: MCPHandler.errorMessage(id: MCPHandler.echoableID(rawID), failure))
        }
        guard let methodValue = fields["method"] else {
            // A response to a server-initiated request. This server never sends any; accept and ignore.
            if fields["result"] != nil || fields["error"] != nil { return MCPOutcome(response: nil) }
            let failure = MCPRPCError.invalidRequest("missing “method”.")
            return MCPOutcome(response: MCPHandler.errorMessage(id: MCPHandler.echoableID(rawID), failure))
        }
        guard let method = methodValue.stringValue, !method.isEmpty else {
            let failure = MCPRPCError.invalidRequest("“method” must be a non-empty string.")
            return MCPOutcome(response: MCPHandler.errorMessage(id: MCPHandler.echoableID(rawID), failure))
        }
        guard let requestID = rawID else {
            handleNotification(method)
            return MCPOutcome(response: nil)
        }
        guard MCPHandler.isValidID(requestID) else {
            let failure = MCPRPCError.invalidRequest("“id” must be a string or a number.")
            return MCPOutcome(response: MCPHandler.errorMessage(id: .null, failure))
        }

        do {
            switch method {
            case "initialize":
                let result = initializeResult(fields["params"])
                return MCPOutcome(response: MCPHandler.successMessage(id: requestID, result), startedSession: true)
            case "ping":
                return MCPOutcome(response: MCPHandler.successMessage(id: requestID, .object([:])))
            case "tools/list":
                let tools = JSONValue.array(MCPTool.allCases.map { $0.definition })
                return MCPOutcome(response: MCPHandler.successMessage(id: requestID, .object(["tools": tools])))
            case "tools/call":
                let result = try await callTool(fields["params"])
                return MCPOutcome(response: MCPHandler.successMessage(id: requestID, result))
            default:
                throw MCPRPCError.methodNotFound(method)
            }
        } catch let failure as MCPRPCError {
            return MCPOutcome(response: MCPHandler.errorMessage(id: requestID, failure))
        } catch {
            let failure = MCPRPCError(code: -32603, message: "Internal error: \(error.localizedDescription)")
            return MCPOutcome(response: MCPHandler.errorMessage(id: requestID, failure))
        }
    }

    private func handleNotification(_ method: String) {
        switch method {
        case "notifications/initialized":
            Log.debug("MCP: client initialized")
        default:
            Log.debug("MCP: ignored notification \(method)")
        }
    }

    private func initializeResult(_ params: JSONValue?) -> JSONValue {
        let requested = params?["protocolVersion"]?.stringValue ?? ""
        let version = MCPHandler.supportedVersions.contains(requested) ? requested : MCPHandler.defaultVersion
        let client = params?["clientInfo"]?["name"]?.stringValue ?? "an MCP client"
        Log.info("MCP: \(client) connected (protocol \(version))")
        return .object([
            "protocolVersion": .string(version),
            "capabilities": .object([
                "tools": .object(["listChanged": false]),
            ]),
            "serverInfo": .object([
                "name": .string(MCPHandler.serverName),
                "title": "Earshot personal memory",
                "version": .string(MCPHandler.serverVersion),
            ]),
            "instructions": .string(MCPHandler.instructions()),
        ])
    }

    private static func instructions() -> String {
        """
        Earshot is the user's always-on personal memory: transcripts of conversations recorded by their \
        Apple Watch or Mac, plus the tasks, commitments, goals and daily digests extracted from them. \
        All tools are read-only. Start with search_memory (keywords) or list_open_loops, read the context \
        with get_transcript, and use ask_memory for questions that need synthesis. Transcripts come from \
        automatic speech recognition and may contain errors; cite moments by their local time and #id. \
        Times are local (\(TimeZone.current.identifier)).
        """
    }

    // MARK: Tools

    private func callTool(_ params: JSONValue?) async throws -> JSONValue {
        guard let object = params?.objectValue else {
            throw MCPRPCError.invalidParams("expected an object with “name” and “arguments”.")
        }
        guard let name = object["name"]?.stringValue, !name.isEmpty else {
            throw MCPRPCError.invalidParams("missing tool “name”.")
        }
        guard let tool = MCPTool(rawValue: name) else {
            throw MCPRPCError.invalidParams("Unknown tool: \(name)")
        }
        let rawArguments: JSONValue = object["arguments"] ?? JSONValue.null
        let arguments: [String: JSONValue]
        switch rawArguments {
        case .object(let values):
            arguments = values
        case .null:
            arguments = [:]
        default:
            return MCPHandler.toolResult("The arguments of \(name) must be a JSON object.", isError: true)
        }
        guard admitToolCall() else {
            return MCPHandler.toolResult("Too many requests: at most \(MCPHandler.maxToolCallsPerMinute) tool calls per minute. Try again shortly.", isError: true)
        }

        Log.info("MCP: tools/call \(name)")
        let clock = MCPClock()
        let input = MCPArguments(values: arguments)
        do {
            let text: String
            switch tool {
            case .searchMemory:
                text = try searchMemory(input, clock: clock)
            case .getTranscript:
                text = try transcript(input, clock: clock)
            case .listOpenLoops:
                text = openLoops(clock: clock)
            case .listGoals:
                text = goalsText(clock: clock)
            case .getDigest:
                text = try digestText(input, clock: clock)
            case .askMemory:
                text = try await askMemory(input, clock: clock)
            }
            return MCPHandler.toolResult(MCPHandler.capped(text), isError: false)
        } catch let failure as MCPToolFailure {
            return MCPHandler.toolResult(failure.message, isError: true)
        } catch {
            Log.error("MCP: \(name) failed: \(error.localizedDescription)")
            return MCPHandler.toolResult("\(name) failed: \(error.localizedDescription)", isError: true)
        }
    }

    private func admitToolCall() -> Bool {
        let now = Date()
        lock.lock()
        defer { lock.unlock() }
        recentToolCalls.removeAll { now.timeIntervalSince($0) > 60 }
        guard recentToolCalls.count < MCPHandler.maxToolCallsPerMinute else { return false }
        recentToolCalls.append(now)
        return true
    }

    // search_memory{query, days?}
    private func searchMemory(_ input: MCPArguments, clock: MCPClock) throws -> String {
        guard let query = input.string("query") else {
            throw MCPToolFailure(message: "“query” is required: the words to look for.")
        }
        let requestedDays = try input.int("days") ?? 0
        let days = max(0, requestedDays)
        let plural = days == 1 ? "" : "s"
        let scope = days > 0 ? "in the last \(days) day\(plural)" : "in the whole archive"
        let hits = memory.search(query, days: days, limit: MCPHandler.searchLimit)

        // Captured items (tasks, facts, …) that mention the query words.
        let terms = MCPHandler.searchTerms(query)
        var related: [Insight] = []
        if !terms.isEmpty {
            let since: Date? = days > 0 ? Date().addingTimeInterval(-Double(days) * 86_400) : nil
            for insight in db.insights(statuses: nil, kinds: nil, since: since, limit: 1_000) {
                let haystack = (insight.title + " " + insight.detail + " " + insight.people.joined(separator: " ")).lowercased()
                if terms.contains(where: { haystack.contains($0) }) {
                    related.append(insight)
                    if related.count >= 10 { break }
                }
            }
        }

        if hits.isEmpty && related.isEmpty {
            return "Nothing matched “\(query)” \(scope). Try other words (names, places, distinctive terms), a longer time range, or get_transcript for a specific day."
        }
        var out = ""
        if hits.isEmpty {
            out += "No transcript lines matched “\(query)” \(scope)."
        } else {
            out += "\(hits.count) transcript line\(hits.count == 1 ? "" : "s") matching “\(query)” \(scope), best match first. \(clock.zoneNote)\n"
            for utterance in hits {
                out += "\n" + MCPHandler.utteranceLine(utterance, timeText: clock.stamp(utterance.startedAt), maxLength: 500)
            }
            out += "\n\nRead the surrounding conversation with get_transcript (date + start_time)."
        }
        if !related.isEmpty {
            out += "\n\nRelated captured items:\n"
            out += related.map { MCPHandler.insightLine($0, clock: clock) }.joined(separator: "\n")
        }
        return out
    }

    // get_transcript{date, start_time?, end_time?}
    private func transcript(_ input: MCPArguments, clock: MCPClock) throws -> String {
        guard let dateText = input.string("date") else {
            throw MCPToolFailure(message: "“date” is required: a local day as yyyy-MM-dd, “today” or “yesterday”.")
        }
        guard let dayStart = MCPHandler.parseDay(dateText) else {
            throw MCPToolFailure(message: "Could not read the date “\(dateText)”. Use yyyy-MM-dd, “today” or “yesterday”.")
        }
        let dayEnd = dayStart.endOfDay
        var from = dayStart
        var to = dayEnd
        if let raw = input.string("start_time") {
            guard let resolved = MCPHandler.resolveTime(raw, on: dayStart) else {
                throw MCPToolFailure(message: "Could not read start_time “\(raw)”. Use 24-hour HH:mm, e.g. \"14:30\".")
            }
            from = resolved
        }
        if let raw = input.string("end_time") {
            guard let resolved = MCPHandler.resolveTime(raw, on: dayStart) else {
                throw MCPToolFailure(message: "Could not read end_time “\(raw)”. Use 24-hour HH:mm, e.g. \"17:00\".")
            }
            to = resolved
        }
        guard to > from else {
            throw MCPToolFailure(message: "end_time must be later than start_time.")
        }

        let window = (from == dayStart && to == dayEnd) ? "whole day" : "\(clock.stamp(from)) to \(clock.stamp(to))"
        let lines = db.utterances(from: from, to: to, limit: MCPHandler.transcriptRowLimit)
        let marks = db.bookmarks(from: from, to: to)

        if lines.isEmpty {
            var text = "No transcript for \(clock.day(dayStart)) (\(window))."
            let seconds = db.recordedSeconds(from: from, to: to)
            if seconds > 0 {
                let minutes = max(1, Int((seconds / 60).rounded()))
                text += " About \(minutes) min of audio were recorded then; it may still be waiting for transcription or contain no speech."
            } else {
                text += " Nothing was recorded in that period."
            }
            if !marks.isEmpty {
                text += "\n\nBookmarks:\n" + marks.map { MCPHandler.bookmarkLine($0, clock: clock) }.joined(separator: "\n")
            }
            return text
        }

        var out = "Transcript for \(clock.day(dayStart)) (\(window)): \(lines.count) line\(lines.count == 1 ? "" : "s"). \(clock.zoneNote) Format: [time] #utterance-id text.\n"
        var used = out.count
        let budget = MCPHandler.maxOutputCharacters - 400
        var markIndex = 0
        var shown = 0
        for utterance in lines {
            while markIndex < marks.count && marks[markIndex].at <= utterance.startedAt {
                let markLine = MCPHandler.bookmarkLine(marks[markIndex], clock: clock)
                out += markLine + "\n"
                used += markLine.count + 1
                markIndex += 1
            }
            let line = MCPHandler.utteranceLine(utterance, timeText: clock.time(utterance.startedAt), maxLength: 1_000)
            if used + line.count + 1 > budget {
                out += "\n… truncated after \(shown) of \(lines.count) lines. To continue, call get_transcript with date \"\(clock.key(utterance.startedAt))\" and start_time \"\(clock.hourMinute(utterance.startedAt))\"."
                return out
            }
            out += line + "\n"
            used += line.count + 1
            shown += 1
        }
        while markIndex < marks.count {
            out += MCPHandler.bookmarkLine(marks[markIndex], clock: clock) + "\n"
            markIndex += 1
        }
        if lines.count >= MCPHandler.transcriptRowLimit {
            out += "\n(Only the first \(MCPHandler.transcriptRowLimit) lines are returned; narrow the window with start_time/end_time.)"
        }
        return out
    }

    // list_open_loops{}
    private func openLoops(clock: MCPClock) -> String {
        let now = Date()
        let open = db.insights(statuses: [.open], kinds: [.commitment, .task, .question], since: nil, limit: 300)
        guard !open.isEmpty else {
            return "No open tasks, commitments or questions right now (as of \(clock.stamp(now)))."
        }
        // Due items first (soonest first), then the rest newest first.
        let sorted = open.sorted { (lhs: Insight, rhs: Insight) -> Bool in
            if let left = lhs.dueAt, let right = rhs.dueAt { return left < right }
            if lhs.dueAt != nil { return true }
            if rhs.dueAt != nil { return false }
            return lhs.createdAt > rhs.createdAt
        }
        let groups: [(InsightKind, String)] = [
            (.commitment, "Commitments"), (.task, "Tasks"), (.question, "Open questions"),
        ]
        var sections: [String] = []
        for (kind, heading) in groups {
            let items = sorted.filter { $0.kind == kind }
            guard !items.isEmpty else { continue }
            let body = items.map { MCPHandler.insightLine($0, clock: clock, now: now) }.joined(separator: "\n")
            sections.append("\(heading) (\(items.count)):\n\(body)")
        }
        return "Open loops as of \(clock.stamp(now)). \(clock.zoneNote)\n\n" + sections.joined(separator: "\n\n")
    }

    // list_goals{}
    private func goalsText(clock: MCPClock) -> String {
        let goals = db.goals(statuses: nil)
        guard !goals.isEmpty else {
            return "No goals recorded yet. Earshot adds goals the user states in conversation or in the app."
        }
        let groups: [(GoalStatus, String)] = [
            (.active, "Active goals"), (.paused, "Paused goals"), (.done, "Completed goals"),
        ]
        var sections: [String] = []
        for (status, heading) in groups {
            let items = goals.filter { $0.status == status }
            guard !items.isEmpty else { continue }
            let lines = items.map { goal -> String in
                var line = "- \(MCPHandler.flatten(goal.title)) · since \(clock.date(goal.createdAt))"
                if let checkIn = goal.lastCheckIn { line += " · last check-in \(clock.stamp(checkIn))" }
                line += " · id \(goal.id)"
                if let why = goal.why.nilIfEmpty { line += "\n  Why: \(MCPHandler.flatten(why).clipped(300))" }
                let notes = goal.notes.sorted { $0.date > $1.date }.prefix(5)
                for note in notes {
                    line += "\n  · \(clock.date(note.date)): \(MCPHandler.flatten(note.text).clipped(240))"
                }
                return line
            }
            sections.append("\(heading) (\(items.count)):\n" + lines.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n")
    }

    // get_digest{date?}
    private func digestText(_ input: MCPArguments, clock: MCPClock) throws -> String {
        let found: Digest?
        var requestedKey: String?
        if let raw = input.string("date") {
            guard let key = MCPHandler.digestKey(raw, clock: clock) else {
                throw MCPToolFailure(message: "Could not read the date “\(raw)”. Use yyyy-MM-dd, “today”, “yesterday” or “week-yyyy-MM-dd”.")
            }
            requestedKey = key
            found = db.digest(day: key)
        } else {
            found = db.digests(limit: 1).first
        }
        guard let digest = found else {
            let available = db.digests(limit: 14).map { $0.day }
            var text = requestedKey.map { "No digest for \($0)." } ?? "No digests yet."
            if available.isEmpty {
                text += " Earshot writes a daily digest each evening once there is transcript for the day."
            } else {
                text += " Available: \(available.joined(separator: ", "))."
            }
            return text
        }
        return "Digest \(digest.day) (written \(clock.stamp(digest.createdAt))):\n\n\(digest.markdown.trimmed)"
    }

    // ask_memory{question}
    private func askMemory(_ input: MCPArguments, clock: MCPClock) async throws -> String {
        guard let question = input.string("question") else {
            throw MCPToolFailure(message: "“question” is required.")
        }
        let reply = try await memory.ask(question, persist: false)
        var text = reply.text.trimmed
        if !reply.citations.isEmpty {
            let sources = reply.citations.map { citation -> String in
                "- #\(citation.utteranceID) [\(clock.stamp(citation.at))] “\(MCPHandler.flatten(citation.quote))”"
            }
            text += "\n\nSources (transcript lines; read more with get_transcript):\n" + sources.joined(separator: "\n")
        }
        return text
    }

    // MARK: Formatting helpers

    private static func utteranceLine(_ utterance: Utterance, timeText: String, maxLength: Int) -> String {
        var line = "[\(timeText)] #\(utterance.id) "
        if let speaker = utterance.speaker?.nilIfEmpty { line += "\(speaker): " }
        return line + flatten(utterance.text).clipped(maxLength)
    }

    private static func bookmarkLine(_ bookmark: StoredBookmark, clock: MCPClock) -> String {
        let time = "[\(clock.time(bookmark.at))]"
        switch bookmark.kind {
        case .bookmark:
            if let note = bookmark.note?.nilIfEmpty { return "\(time) (bookmark) \(flatten(note).clipped(300))" }
            return "\(time) (bookmark)"
        case .privacyPauseStart:
            return "\(time) (recording paused for privacy)"
        case .privacyPauseEnd:
            return "\(time) (recording resumed)"
        }
    }

    private static func insightLine(_ insight: Insight, clock: MCPClock, now: Date = Date()) -> String {
        var line = "- [\(insight.kind.rawValue)] \(flatten(insight.title))"
        if let due = insight.dueAt {
            line += " · due \(clock.stamp(due))"
            if insight.status == .open && due < now { line += " (overdue)" }
        }
        if !insight.people.isEmpty { line += " · with \(insight.people.joined(separator: ", "))" }
        if insight.status != .open { line += " · \(insight.status.rawValue)" }
        line += " · captured \(clock.stamp(insight.sourceFrom ?? insight.createdAt)) · id \(insight.id)"
        if let detail = insight.detail.nilIfEmpty { line += "\n  \(flatten(detail).clipped(300))" }
        return line
    }

    /// Collapses newlines and runs of whitespace into single spaces.
    private static func flatten(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    }

    private static func capped(_ text: String) -> String {
        guard text.count > maxOutputCharacters else { return text }
        return String(text.prefix(maxOutputCharacters)) + "\n… (output truncated at \(maxOutputCharacters) characters)"
    }

    /// Lowercased alphanumeric words of at least 3 characters.
    private static func searchTerms(_ query: String) -> [String] {
        var words: [String] = []
        var current = ""
        for character in query.lowercased() {
            if character.isLetter || character.isNumber {
                current.append(character)
            } else {
                if current.count >= 3 && !words.contains(current) { words.append(current) }
                current = ""
            }
        }
        if current.count >= 3 && !words.contains(current) { words.append(current) }
        return Array(words.prefix(8))
    }

    // MARK: Date helpers

    /// Start of the local day named by "today", "yesterday", "yyyy-MM-dd" (or any ISO date-time).
    private static func parseDay(_ raw: String) -> Date? {
        let text = raw.trimmed.lowercased()
        let today = Date().startOfDay
        switch text {
        case "today":
            return today
        case "yesterday":
            return Calendar.current.date(byAdding: .day, value: -1, to: today)
        default:
            return DateParsing.parse(raw.trimmed)?.startOfDay
        }
    }

    /// Digest key: "yyyy-MM-dd" or "week-yyyy-MM-dd".
    private static func digestKey(_ raw: String, clock: MCPClock) -> String? {
        let text = raw.trimmed
        if text.lowercased().hasPrefix("week-") {
            guard let day = parseDay(String(text.dropFirst(5))) else { return nil }
            return "week-" + clock.key(day)
        }
        guard let day = parseDay(text) else { return nil }
        return clock.key(day)
    }

    /// A time on `dayStart`'s day ("14:30", "9:05", "2:30 PM", "2pm", "24:00"), or a full ISO date-time.
    private static func resolveTime(_ raw: String, on dayStart: Date) -> Date? {
        let text = raw.trimmed
        if text.count >= 10, text.contains("-"), let full = DateParsing.parse(text) {
            return full
        }
        guard let clockTime = parseClockTime(text) else { return nil }
        if clockTime.hour == 24 { return dayStart.endOfDay }
        return Calendar.current.date(bySettingHour: clockTime.hour, minute: clockTime.minute, second: 0, of: dayStart)
    }

    private static func parseClockTime(_ raw: String) -> (hour: Int, minute: Int)? {
        var text = raw.lowercased().replacingOccurrences(of: ".", with: "").trimmed
        var meridiem: String?
        if text.hasSuffix("am") || text.hasSuffix("pm") {
            meridiem = String(text.suffix(2))
            text = String(text.dropLast(2)).trimmed
        }
        let parts = text.split(separator: ":", omittingEmptySubsequences: false).map { String($0).trimmed }
        guard (1...3).contains(parts.count), let rawHour = Int(parts[0]) else { return nil }
        var minute = 0
        if parts.count >= 2 {
            guard let parsedMinute = Int(parts[1]), (0...59).contains(parsedMinute) else { return nil }
            minute = parsedMinute
        }
        if parts.count == 3 {
            guard let second = Int(parts[2]), (0...59).contains(second) else { return nil }
        }
        var hour = rawHour
        if let meridiem {
            guard (1...12).contains(hour) else { return nil }
            if meridiem == "am" {
                hour = hour == 12 ? 0 : hour
            } else {
                hour = hour == 12 ? 12 : hour + 12
            }
        } else {
            guard (0...24).contains(hour) else { return nil }
            if hour == 24 && minute != 0 { return nil }
        }
        return (hour: hour, minute: minute)
    }

    // MARK: JSON-RPC helpers

    private static func isValidID(_ id: JSONValue) -> Bool {
        switch id {
        case .string, .number: return true
        default: return false
        }
    }

    private static func echoableID(_ id: JSONValue?) -> JSONValue {
        guard let id, isValidID(id) else { return .null }
        return id
    }

    private static func successMessage(id: JSONValue, _ result: JSONValue) -> JSONValue {
        .object(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private static func errorMessage(id: JSONValue, _ failure: MCPRPCError) -> JSONValue {
        .object([
            "jsonrpc": "2.0",
            "id": id,
            "error": .object([
                "code": .number(Double(failure.code)),
                "message": .string(failure.message),
            ]),
        ])
    }

    private static func toolResult(_ text: String, isError: Bool) -> JSONValue {
        .object([
            "content": .array([.object(["type": "text", "text": .string(text.isEmpty ? "(no result)" : text)])]),
            "isError": .bool(isError),
        ])
    }

    private static func reply(_ value: JSONValue, status: Int, sessionID: String? = nil) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let body: Data
        do {
            body = try encoder.encode(value)
        } catch {
            Log.error("MCP: could not encode a response: \(error.localizedDescription)")
            body = Data(#"{"error":{"code":-32603,"message":"Internal error"},"id":null,"jsonrpc":"2.0"}"#.utf8)
        }
        var headers = ["Content-Type": "application/json", "Cache-Control": "no-store"]
        if let sessionID { headers["Mcp-Session-Id"] = sessionID }
        return HTTPResponse(status: status, headers: headers, body: body)
    }

    // MARK: Security helpers

    private static func isWellFormedToken(_ token: String) -> Bool {
        token.count >= 32 && token.count <= 256 && token.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    /// `byteCount` random bytes, hex encoded.
    private static func randomHex(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: max(1, byteCount))
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            Log.error("MCP: SecRandomCopyBytes failed (\(status)); using the system RNG")
            var generator = SystemRandomNumberGenerator()
            for index in bytes.indices {
                bytes[index] = UInt8.random(in: UInt8.min...UInt8.max, using: &generator)
            }
        }
        let digits = Array("0123456789abcdef")
        var text = ""
        text.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            text.append(digits[Int(byte >> 4)])
            text.append(digits[Int(byte & 0x0F)])
        }
        return text
    }

    /// Compares every byte regardless of where the first difference is.
    private static func constantTimeEquals(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        var difference: UInt8 = a.count == b.count ? 0 : 1
        let length = max(a.count, b.count)
        for index in 0..<length {
            let x: UInt8 = index < a.count ? a[index] : 0
            let y: UInt8 = index < b.count ? b[index] : 0
            difference |= x ^ y
        }
        return difference == 0 && !a.isEmpty
    }
}
