//  APIRouter.swift
//  Maps HTTP requests from the watch to the Mac's services.
//
//  GET  /api/v1/hello      -> ServerHello            (no auth)
//  POST /api/v1/pair       -> PairResponse           (no auth)
//  POST /api/v1/segments   -> SegmentAck             (raw audio + SegmentMeta headers)
//  POST /api/v1/sync       -> SyncResponse
//  POST /api/v1/answers    -> OKResponse             (forwarded to the bridge)
//  POST /api/v1/requests   -> WatchRequestAck        (forwarded to the bridge)
//  POST /api/v1/bookmarks  -> OKResponse             (forwarded to the bridge)
//  POST /mcp               -> MCP JSON-RPC           (only while Settings → mcpEnabled; MCPHandler
//                                                    checks its own bearer token, not the watch pairing)
//
//  Every request carrying an Origin header that is not localhost is rejected with
//  403 (DNS-rebinding protection; the watch and MCP clients send no Origin).

import Foundation

@MainActor
protocol WatchBridge: AnyObject {
    func watchDidAnswer(_ answer: PromptAnswer, device: PairedDevice) async
    func watchDidRequest(_ request: WatchRequest, device: PairedDevice) async -> WatchRequestAck
    func watchDidBookmark(_ bookmark: Bookmark, device: PairedDevice) async
    func todaySnapshot() async -> TodaySnapshot
}

/// An HTTP error raised while routing; becomes an `APIErrorBody` response.
private struct APIFailure: Error {
    let status: Int
    let message: String
}

/// Resumes a continuation exactly once, whichever of the work or the deadline finishes first.
private final class APIDeadlineGate<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T?, Never>?

    func install(_ continuation: CheckedContinuation<T?, Never>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func resolve(_ value: T?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}

/// Runs `operation` in its own task and waits at most `seconds` for it. On timeout returns nil
/// while the operation keeps running to completion in the background.
private func awaitWithDeadline<T>(_ seconds: TimeInterval,
                                  _ operation: @escaping @Sendable () async -> T) async -> T? {
    let gate = APIDeadlineGate<T>()
    return await withCheckedContinuation { (continuation: CheckedContinuation<T?, Never>) in
        gate.install(continuation)
        Task {
            let value = await operation()
            gate.resolve(value)
        }
        Task {
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            gate.resolve(nil)
        }
    }
}

final class APIRouter: @unchecked Sendable {
    /// Delivered-but-unanswered prompts stay visible on the watch this long.
    private static let deliveredWindow: TimeInterval = 6 * 60 * 60
    /// How long a watch request waits for the bridge before getting an early acknowledgement.
    private static let bridgeTimeout: TimeInterval = 20
    private static let authenticatedPaths: Set<String> = [
        EarshotAPI.Path.segments, EarshotAPI.Path.sync, EarshotAPI.Path.answers,
        EarshotAPI.Path.requests, EarshotAPI.Path.bookmarks,
    ]

    private let db: Database
    private let pairing: PairingManager
    private let pipeline: IngestPipeline
    private let mcpLock = NSLock()
    /// Guarded by `mcpLock`.
    private var mcpHandler: MCPHandler?

    weak var bridge: WatchBridge?

    /// Personal-memory MCP endpoint (set by AppModel). Served only while `mcpEnabled` is on.
    var mcp: MCPHandler? {
        get {
            mcpLock.lock()
            defer { mcpLock.unlock() }
            return mcpHandler
        }
        set {
            mcpLock.lock()
            mcpHandler = newValue
            mcpLock.unlock()
        }
    }

    init(db: Database, pairing: PairingManager, pipeline: IngestPipeline) {
        self.db = db
        self.pairing = pairing
        self.pipeline = pipeline
    }

    func handle(_ request: HTTPRequest) async -> HTTPResponse {
        let response: HTTPResponse
        do {
            response = try await route(request)
        } catch let failure as APIFailure {
            response = HTTPResponse.error(failure.status, failure.message)
        } catch {
            Log.error("API \(request.method) \(request.path) failed: \(error.localizedDescription)")
            response = HTTPResponse.error(500, error.localizedDescription)
        }
        if response.status >= 400 {
            Log.info("API \(request.method) \(request.path) → \(response.status)")
        }
        return response
    }

    // MARK: - Routing

    private func route(_ request: HTTPRequest) async throws -> HTTPResponse {
        let path = APIRouter.normalisedPath(request.path)
        guard APIRouter.isAllowedOrigin(request.header("Origin")) else {
            throw APIFailure(status: 403, message: "Requests from web pages are not allowed.")
        }
        if path == EarshotAPI.Path.mcp {
            // MCP clients authenticate with the MCP token (checked by MCPHandler), not a watch pairing.
            guard SettingsStore.current.mcpEnabled, let mcp = self.mcp else {
                throw APIFailure(status: 404, message: "Not found: \(path)")
            }
            return await mcp.handle(request)
        }
        if path == EarshotAPI.Path.hello {
            try APIRouter.require(request, method: "GET")
            return hello()
        }
        if path == EarshotAPI.Path.pair {
            try APIRouter.require(request, method: "POST")
            return try pair(request)
        }
        guard APIRouter.authenticatedPaths.contains(path) else {
            throw APIFailure(status: 404, message: "Not found: \(path)")
        }
        try APIRouter.require(request, method: "POST")
        guard let device = pairing.authenticate(authorizationHeader: request.header(EarshotAPI.Header.authorization)) else {
            throw APIFailure(status: 401, message: "Unauthorized. Pair this watch again from the Devices screen on your Mac.")
        }
        switch path {
        case EarshotAPI.Path.segments:
            return try uploadSegment(request, device: device)
        case EarshotAPI.Path.sync:
            return try await handleSync(request, device: device)
        case EarshotAPI.Path.answers:
            return try await answer(request, device: device)
        case EarshotAPI.Path.requests:
            return try await watchRequest(request, device: device)
        case EarshotAPI.Path.bookmarks:
            return try await bookmark(request, device: device)
        default:
            throw APIFailure(status: 404, message: "Not found: \(path)")
        }
    }

    // MARK: - Unauthenticated

    private func hello() -> HTTPResponse {
        HTTPResponse.json(ServerHello(macName: SettingsStore.current.effectiveMacName,
                                      protocolVersion: EarshotAPI.protocolVersion,
                                      serverTime: Date()))
    }

    private func pair(_ request: HTTPRequest) throws -> HTTPResponse {
        let pairRequest = try APIRouter.decodeBody(PairRequest.self, from: request)
        guard let device = pairing.pair(pairRequest) else {
            throw APIFailure(status: 403, message: "Wrong or expired pairing code. Use the code shown on your Mac.")
        }
        return HTTPResponse.json(PairResponse(token: device.token,
                                              macName: SettingsStore.current.effectiveMacName,
                                              protocolVersion: EarshotAPI.protocolVersion))
    }

    // MARK: - Segments

    private func uploadSegment(_ request: HTTPRequest, device: PairedDevice) throws -> HTTPResponse {
        guard let meta = SegmentMeta(headers: request.headers) else {
            throw APIFailure(status: 400, message: "Missing or invalid segment headers (\(EarshotAPI.Header.segmentID) and \(EarshotAPI.Header.startedAt) are required).")
        }
        guard !request.body.isEmpty else {
            throw APIFailure(status: 400, message: "The audio body is empty.")
        }
        let ack = pipeline.ingest(audio: request.body, meta: meta)
        touch(device)
        if !ack.accepted {
            Log.error("Segment \(meta.id) from “\(device.name)” was not stored: \(ack.message ?? "unknown error")")
        }
        return HTTPResponse.json(ack, status: ack.accepted ? 200 : 500)
    }

    // MARK: - Sync

    private func handleSync(_ request: HTTPRequest, device: PairedDevice) async throws -> HTTPResponse {
        let report = try APIRouter.decodeBody(WatchStatusReport.self, from: request)
        let now = Date()
        let settings = SettingsStore.current

        // Device status.
        guard var updated = db.device(token: device.token) else {
            throw APIFailure(status: 401, message: "This watch is no longer paired.")
        }
        updated.lastSeen = now
        updated.lastStatus = report
        if let name = report.deviceName.nilIfEmpty { updated.name = name }
        db.upsertDevice(updated)
        EarshotEvents.post(.devices)

        // Prompts the watch has shown.
        var promptsChanged = false
        var seen = Set<String>()
        for id in report.deliveredPromptIDs where !seen.contains(id) {
            seen.insert(id)
            guard var prompt = db.prompt(id: id), prompt.status == .pending else { continue }
            prompt.status = .delivered
            if prompt.deliveredAt == nil { prompt.deliveredAt = now }
            db.upsertPrompt(prompt)
            promptsChanged = true
        }

        // Expire stale prompts and collect the ones the watch should show.
        let cutoff = now.addingTimeInterval(-APIRouter.deliveredWindow)
        var outgoing: [StoredPrompt] = []
        for var prompt in db.prompts(statuses: [.pending, .delivered], limit: 500) {
            if let expiresAt = prompt.expiresAt, expiresAt < now {
                prompt.status = .expired
                db.upsertPrompt(prompt)
                promptsChanged = true
                continue
            }
            switch prompt.status {
            case .pending:
                outgoing.append(prompt)
            case .delivered:
                if (prompt.deliveredAt ?? prompt.createdAt) >= cutoff { outgoing.append(prompt) }
            case .queued, .awaitingVoice, .answered, .dismissed, .expired:
                break
            }
        }
        if promptsChanged { EarshotEvents.post(.prompts) }

        outgoing.sort { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority > rhs.priority }
            return lhs.createdAt < rhs.createdAt
        }

        let today: TodaySnapshot
        if let bridge = self.bridge {
            today = await bridge.todaySnapshot()
        } else {
            today = TodaySnapshot.empty
        }

        return HTTPResponse.json(SyncResponse(serverTime: now,
                                              macName: settings.effectiveMacName,
                                              prompts: outgoing.map { $0.wire },
                                              today: today,
                                              settings: settings.remoteWatchSettings))
    }

    // MARK: - Forwarded to the bridge

    private func answer(_ request: HTTPRequest, device: PairedDevice) async throws -> HTTPResponse {
        let answer = try APIRouter.decodeBody(PromptAnswer.self, from: request)
        touch(device)
        guard let bridge = self.bridge else { throw APIRouter.notReady }
        let finished: Void? = await awaitWithDeadline(APIRouter.bridgeTimeout) {
            await bridge.watchDidAnswer(answer, device: device)
        }
        if finished == nil {
            Log.info("Answer to prompt \(answer.promptID) is still being processed; acknowledged early")
            return HTTPResponse.json(OKResponse(ok: true, message: "Received. Still processing."))
        }
        return HTTPResponse.json(OKResponse(ok: true, message: nil))
    }

    private func watchRequest(_ request: HTTPRequest, device: PairedDevice) async throws -> HTTPResponse {
        let watchRequest = try APIRouter.decodeBody(WatchRequest.self, from: request)
        touch(device)
        guard let bridge = self.bridge else { throw APIRouter.notReady }
        let ack: WatchRequestAck? = await awaitWithDeadline(APIRouter.bridgeTimeout) {
            await bridge.watchDidRequest(watchRequest, device: device)
        }
        if let ack { return HTTPResponse.json(ack) }
        Log.info("Watch request \(watchRequest.id) is still running; acknowledged early")
        return HTTPResponse.json(WatchRequestAck(id: watchRequest.id, accepted: true,
                                                 message: "Working on it. The answer will appear on your watch."))
    }

    private func bookmark(_ request: HTTPRequest, device: PairedDevice) async throws -> HTTPResponse {
        let bookmark = try APIRouter.decodeBody(Bookmark.self, from: request)
        touch(device)
        guard let bridge = self.bridge else { throw APIRouter.notReady }
        let finished: Void? = await awaitWithDeadline(APIRouter.bridgeTimeout) {
            await bridge.watchDidBookmark(bookmark, device: device)
        }
        if finished == nil {
            Log.info("Bookmark \(bookmark.id) is still being processed; acknowledged early")
        }
        return HTTPResponse.json(OKResponse(ok: true, message: nil))
    }

    // MARK: - Helpers

    private static let notReady = APIFailure(status: 503, message: "The Mac app is still starting up. Try again in a moment.")

    /// Records that the device was seen (re-reads it so a concurrent /sync status is not overwritten).
    private func touch(_ device: PairedDevice) {
        guard var current = db.device(token: device.token) else { return }
        current.lastSeen = Date()
        db.upsertDevice(current)
        EarshotEvents.post(.devices)
    }

    /// True when there is no Origin header, or it names this machine's loopback host
    /// (DNS-rebinding protection: a web page elsewhere must not reach the local API).
    private static func isAllowedOrigin(_ origin: String?) -> Bool {
        guard let raw = origin?.trimmed, !raw.isEmpty else { return true }
        guard let host = URLComponents(string: raw)?.host?.lowercased(), !host.isEmpty else { return false }
        var bare = host
        if bare.hasPrefix("[") && bare.hasSuffix("]") {
            bare = String(bare.dropFirst().dropLast())
        }
        return bare == "localhost" || bare == "127.0.0.1" || bare == "::1"
    }

    private static func require(_ request: HTTPRequest, method: String) throws {
        guard request.method.uppercased() == method else {
            throw APIFailure(status: 405, message: "Use \(method) for this endpoint.")
        }
    }

    private static func normalisedPath(_ path: String) -> String {
        var result = path
        while result.count > 1 && result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }

    private static func decodeBody<T: Decodable>(_ type: T.Type, from request: HTTPRequest) throws -> T {
        guard !request.body.isEmpty else {
            throw APIFailure(status: 400, message: "Missing JSON body.")
        }
        do {
            return try EarshotAPI.makeDecoder().decode(T.self, from: request.body)
        } catch {
            throw APIFailure(status: 400, message: "Invalid JSON: \(describe(error))")
        }
    }

    private static func describe(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else { return error.localizedDescription }
        switch decodingError {
        case .keyNotFound(let key, _):
            return "missing field '\(key.stringValue)'"
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return path.isEmpty ? context.debugDescription : "\(path): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
