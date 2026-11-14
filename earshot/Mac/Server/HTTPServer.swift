//  HTTPServer.swift
//  Minimal HTTP/1.1 server on Network.framework for the watch API.
//
//  One request per connection: the server reads until the head and the
//  Content-Length (or chunked) body are complete, calls the handler in a Task,
//  writes the response with Content-Length and "Connection: close", then
//  cancels the connection. The listener is advertised over Bonjour.

import Foundation
import Network

// MARK: - Request / response values

struct HTTPRequest: Sendable {
    var method: String                 // "GET", "POST"
    var path: String                   // without query, e.g. "/api/v1/sync"
    var query: [String: String]
    var headers: [String: String]      // keys lowercased
    var body: Data

    /// Case-insensitive header lookup.
    func header(_ name: String) -> String? {
        let key = name.lowercased()
        if let value = headers[key] { return value }
        return headers.first(where: { $0.key.lowercased() == key })?.value
    }
}

struct HTTPResponse: Sendable {
    var status: Int
    var headers: [String: String]
    var body: Data

    /// JSON body encoded with `EarshotAPI.makeEncoder()` (dates as seconds since 1970).
    static func json<T: Encodable>(_ value: T, status: Int = 200) -> HTTPResponse {
        do {
            let data = try EarshotAPI.makeEncoder().encode(value)
            return HTTPResponse(status: status,
                                headers: ["Content-Type": "application/json; charset=utf-8",
                                          "Cache-Control": "no-store"],
                                body: data)
        } catch {
            Log.error("HTTP: could not encode \(T.self): \(error.localizedDescription)")
            return HTTPResponse.error(500, "The server could not encode its response.")
        }
    }

    /// `APIErrorBody` JSON.
    static func error(_ status: Int, _ message: String) -> HTTPResponse {
        let fallback = Data("{\"error\":\"Internal server error\"}".utf8)
        let data = (try? EarshotAPI.makeEncoder().encode(APIErrorBody(error: message))) ?? fallback
        return HTTPResponse(status: status,
                            headers: ["Content-Type": "application/json; charset=utf-8",
                                      "Cache-Control": "no-store"],
                            body: data)
    }

    static func text(_ text: String, status: Int = 200) -> HTTPResponse {
        HTTPResponse(status: status,
                     headers: ["Content-Type": "text/plain; charset=utf-8"],
                     body: Data(text.utf8))
    }
}

// MARK: - Parser

/// Pure parser (unit-tested). Returns nil until the full head + Content-Length body is present.
enum HTTPParser {
    static let maxBodyBytes: Int = 64 * 1024 * 1024

    static func parse(_ buffer: Data) -> (request: HTTPRequest, consumed: Int)? {
        if case .complete(let request, let consumed) = evaluateHTTPBuffer(buffer) {
            return (request: request, consumed: consumed)
        }
        return nil
    }

    static func serialize(_ response: HTTPResponse) -> Data {
        var head = "HTTP/1.1 \(response.status) \(httpReasonPhrase(response.status))\r\n"
        var hasContentType = false
        for (name, value) in response.headers.sorted(by: { $0.key < $1.key }) {
            let lower = name.lowercased()
            if lower == "content-length" || lower == "connection" || lower == "transfer-encoding" { continue }
            if lower == "content-type" { hasContentType = true }
            // Strip line breaks so a header value can never split the response. Use isNewline:
            // "\r\n" is a single Character, equal to neither "\r" nor "\n", and a CR or LF
            // never joins any other grapheme cluster, so this removes every CR and LF.
            let safeName = name.filter { !$0.isNewline && $0 != ":" }
            let safeValue = value.filter { !$0.isNewline }
            guard !safeName.isEmpty else { continue }
            head += "\(safeName): \(safeValue)\r\n"
        }
        if !hasContentType && !response.body.isEmpty {
            head += "Content-Type: application/octet-stream\r\n"
        }
        head += "Server: Earshot\r\n"
        head += "Content-Length: \(response.body.count)\r\n"
        head += "Connection: close\r\n\r\n"
        var data = Data(head.utf8)
        data.append(response.body)
        return data
    }
}

// MARK: - Parser internals (file-private)

fileprivate let httpMaxHeaderBytes = 64 * 1024
fileprivate let httpHeadTerminator = Data([13, 10, 13, 10])
fileprivate let httpLineTerminator = Data([13, 10])

fileprivate enum HTTPBufferState {
    /// More bytes are needed. `headerComplete` once the head was parsed.
    case needMore(headerComplete: Bool, expectsContinue: Bool)
    /// The request can never become valid; answer with `status` and close.
    case reject(status: Int, message: String)
    case complete(request: HTTPRequest, consumed: Int)
}

fileprivate struct HTTPHead {
    var method: String
    var target: String
    var headers: [String: String]
    var contentLength: Int?
    var isChunked: Bool
    var expectsContinue: Bool
}

fileprivate struct HTTPHeadError: Error {
    let message: String
}

fileprivate enum HTTPChunkScan {
    case incomplete
    case invalid(String)
    case tooLarge
    /// `end` is the absolute buffer index just past the final CRLF.
    case complete(body: Data, end: Int)
}

/// Examines everything received so far on a connection.
fileprivate func evaluateHTTPBuffer(_ buffer: Data) -> HTTPBufferState {
    let start = buffer.startIndex
    guard let headRange = buffer.range(of: httpHeadTerminator, options: [], in: start..<buffer.endIndex) else {
        if buffer.count > httpMaxHeaderBytes {
            return .reject(status: 431, message: "Request headers are too large.")
        }
        return .needMore(headerComplete: false, expectsContinue: false)
    }
    let headerLength = headRange.upperBound - start
    if headerLength > httpMaxHeaderBytes {
        return .reject(status: 431, message: "Request headers are too large.")
    }
    let headData = buffer[start..<headRange.lowerBound]
    let headText = String(data: headData, encoding: .utf8)
        ?? String(data: headData, encoding: .isoLatin1)
        ?? String(decoding: headData, as: UTF8.self)

    let head: HTTPHead
    switch parseHTTPHead(headText) {
    case .success(let parsed):
        head = parsed
    case .failure(let failure):
        return .reject(status: 400, message: failure.message)
    }

    let bodyStart = headRange.upperBound
    if head.isChunked {
        switch scanChunkedBody(buffer, from: bodyStart, collect: false) {
        case .incomplete:
            return .needMore(headerComplete: true, expectsContinue: head.expectsContinue)
        case .invalid(let message):
            return .reject(status: 400, message: message)
        case .tooLarge:
            return .reject(status: 413, message: "Request body exceeds the 64 MB limit.")
        case .complete:
            // Second pass copies the body only once the whole message is present.
            guard case .complete(let body, let end) = scanChunkedBody(buffer, from: bodyStart, collect: true) else {
                return .reject(status: 400, message: "Malformed chunked body.")
            }
            return .complete(request: makeHTTPRequest(head, body: body), consumed: end - start)
        }
    }

    let length = head.contentLength ?? 0
    if length > HTTPParser.maxBodyBytes {
        return .reject(status: 413, message: "Request body exceeds the 64 MB limit.")
    }
    let available = buffer.endIndex - bodyStart
    if available < length {
        return .needMore(headerComplete: true, expectsContinue: head.expectsContinue)
    }
    let body = length > 0 ? Data(buffer[bodyStart..<(bodyStart + length)]) : Data()
    return .complete(request: makeHTTPRequest(head, body: body), consumed: headerLength + length)
}

fileprivate func parseHTTPHead(_ text: String) -> Result<HTTPHead, HTTPHeadError> {
    var lines = text.components(separatedBy: "\r\n")
    // RFC 9112 §2.2: ignore empty lines before the request line.
    while let first = lines.first, first.isEmpty { lines.removeFirst() }
    guard !lines.isEmpty else { return .failure(HTTPHeadError(message: "Empty request.")) }

    let requestLine = lines.removeFirst()
    let parts = requestLine.split(separator: " ", omittingEmptySubsequences: true)
    guard parts.count == 3, parts[2].hasPrefix("HTTP/") else {
        return .failure(HTTPHeadError(message: "Malformed request line."))
    }
    let method = String(parts[0]).uppercased()
    guard !method.isEmpty, method.allSatisfy({ $0.isASCII && $0.isLetter }) else {
        return .failure(HTTPHeadError(message: "Malformed request method."))
    }

    var headers: [String: String] = [:]
    var lastKey: String?
    for line in lines where !line.isEmpty {
        if let firstCharacter = line.first, firstCharacter == " " || firstCharacter == "\t" {
            // Obsolete line folding: continuation of the previous header.
            guard let key = lastKey else { return .failure(HTTPHeadError(message: "Malformed header folding.")) }
            headers[key, default: ""] += " " + line.trimmingCharacters(in: .whitespaces)
            continue
        }
        guard let colon = line.firstIndex(of: ":") else {
            return .failure(HTTPHeadError(message: "Malformed header line."))
        }
        let key = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
        let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return .failure(HTTPHeadError(message: "Empty header name.")) }
        if let existing = headers[key] {
            headers[key] = existing + ", " + value
        } else {
            headers[key] = value
        }
        lastKey = key
    }

    let transferEncoding = headers["transfer-encoding"]?.lowercased() ?? ""
    let isChunked = transferEncoding.contains("chunked")
    if !transferEncoding.isEmpty && !isChunked {
        return .failure(HTTPHeadError(message: "Unsupported Transfer-Encoding."))
    }

    var contentLength: Int?
    if !isChunked, let raw = headers["content-length"] {
        let values = Set(raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
        guard values.count == 1, let only = values.first, let number = Int(only), number >= 0 else {
            return .failure(HTTPHeadError(message: "Invalid Content-Length."))
        }
        contentLength = number
    }

    let expectsContinue = headers["expect"]?.lowercased().contains("100-continue") ?? false
    return .success(HTTPHead(method: method, target: String(parts[1]), headers: headers,
                             contentLength: contentLength, isChunked: isChunked,
                             expectsContinue: expectsContinue))
}

/// Walks a chunked body starting at `start`. With `collect == false` nothing is copied.
fileprivate func scanChunkedBody(_ buffer: Data, from start: Int, collect: Bool) -> HTTPChunkScan {
    let end = buffer.endIndex
    var cursor = start
    var body = Data()
    var total = 0
    while true {
        guard let lineRange = buffer.range(of: httpLineTerminator, options: [], in: cursor..<end) else {
            return end - cursor > 1_024 ? .invalid("Malformed chunk header.") : .incomplete
        }
        let sizeLine = String(decoding: buffer[cursor..<lineRange.lowerBound], as: UTF8.self)
        let sizeText = sizeLine.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        guard !sizeText.isEmpty, let size = Int(sizeText, radix: 16), size >= 0 else {
            return .invalid("Malformed chunk size.")
        }
        cursor = lineRange.upperBound
        if size == 0 {
            // Optional trailer fields, terminated by an empty line.
            while true {
                guard let trailerRange = buffer.range(of: httpLineTerminator, options: [], in: cursor..<end) else {
                    return end - cursor > httpMaxHeaderBytes ? .invalid("Trailer section too large.") : .incomplete
                }
                let isBlank = trailerRange.lowerBound == cursor
                cursor = trailerRange.upperBound
                if isBlank { return .complete(body: body, end: cursor) }
            }
        }
        if size > HTTPParser.maxBodyBytes - total { return .tooLarge }
        total += size
        guard end - cursor >= size + 2 else { return .incomplete }
        if collect { body.append(buffer[cursor..<(cursor + size)]) }
        cursor += size
        guard buffer[cursor] == 13, buffer[cursor + 1] == 10 else {
            return .invalid("Malformed chunk terminator.")
        }
        cursor += 2
    }
}

fileprivate func makeHTTPRequest(_ head: HTTPHead, body: Data) -> HTTPRequest {
    let target = splitHTTPTarget(head.target)
    return HTTPRequest(method: head.method, path: target.path, query: target.query,
                       headers: head.headers, body: body)
}

/// Splits a request target into a percent-decoded path and query dictionary.
fileprivate func splitHTTPTarget(_ target: String) -> (path: String, query: [String: String]) {
    var rest = Substring(target)
    // Absolute-form ("http://host:port/path?x") → keep only the path and query.
    if let schemeRange = rest.range(of: "://") {
        let afterScheme = rest[schemeRange.upperBound...]
        if let slash = afterScheme.firstIndex(of: "/") {
            rest = afterScheme[slash...]
        } else {
            rest = "/"
        }
    }
    if let hash = rest.firstIndex(of: "#") {
        rest = rest[..<hash]
    }
    var queryText: Substring = ""
    if let questionMark = rest.firstIndex(of: "?") {
        queryText = rest[rest.index(after: questionMark)...]
        rest = rest[..<questionMark]
    }
    let rawPath = rest.isEmpty ? "/" : String(rest)
    let path = rawPath.removingPercentEncoding ?? rawPath
    return (path: path, query: parseHTTPQuery(queryText))
}

fileprivate func parseHTTPQuery(_ text: Substring) -> [String: String] {
    var result: [String: String] = [:]
    for pair in text.split(separator: "&", omittingEmptySubsequences: true) {
        let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard let rawKey = parts.first else { continue }
        let key = decodeHTTPQueryComponent(String(rawKey))
        guard !key.isEmpty else { continue }
        let value = parts.count > 1 ? decodeHTTPQueryComponent(String(parts[1])) : ""
        result[key] = value
    }
    return result
}

fileprivate func decodeHTTPQueryComponent(_ text: String) -> String {
    let spaced = text.replacingOccurrences(of: "+", with: " ")
    return spaced.removingPercentEncoding ?? spaced
}

fileprivate func httpReasonPhrase(_ status: Int) -> String {
    switch status {
    case 100: return "Continue"
    case 200: return "OK"
    case 201: return "Created"
    case 202: return "Accepted"
    case 204: return "No Content"
    case 400: return "Bad Request"
    case 401: return "Unauthorized"
    case 403: return "Forbidden"
    case 404: return "Not Found"
    case 405: return "Method Not Allowed"
    case 408: return "Request Timeout"
    case 409: return "Conflict"
    case 413: return "Content Too Large"
    case 415: return "Unsupported Media Type"
    case 422: return "Unprocessable Content"
    case 429: return "Too Many Requests"
    case 431: return "Request Header Fields Too Large"
    case 500: return "Internal Server Error"
    case 501: return "Not Implemented"
    case 503: return "Service Unavailable"
    case 507: return "Insufficient Storage"
    default:
        switch status {
        case 200..<300: return "Success"
        case 300..<400: return "Redirection"
        case 400..<500: return "Client Error"
        default: return "Server Error"
        }
    }
}

// MARK: - Server

/// Per-connection state. Only touched on the server's serial queue.
private final class HTTPConnectionContext: @unchecked Sendable {
    let connection: NWConnection
    let openedAt = Date()
    var buffer = Data()
    var activity = 0
    var responding = false
    var closed = false
    var sentContinue = false

    init(connection: NWConnection) {
        self.connection = connection
    }
}

private struct HTTPServerError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class HTTPServer: @unchecked Sendable {
    private static let idleTimeout: TimeInterval = 60
    private static let maxHandlerTime: TimeInterval = 600
    private static let receiveChunk = 1 << 20

    private let listenPort: UInt16
    private let handler: @Sendable (HTTPRequest) async -> HTTPResponse
    private let queue = DispatchQueue(label: "com.example.earshot.http-server", qos: .userInitiated)

    private let lock = NSLock()
    private var listener: NWListener?
    private var running = false
    private var lastErrorText: String?
    private var stateHandler: (@Sendable (_ running: Bool, _ error: String?) -> Void)?

    /// Open connections. Only touched on `queue`.
    private var connections: [ObjectIdentifier: HTTPConnectionContext] = [:]

    init(port: UInt16, handler: @escaping @Sendable (HTTPRequest) async -> HTTPResponse) {
        self.listenPort = port
        self.handler = handler
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }

    var port: UInt16 { listenPort }

    var lastError: String? {
        lock.lock()
        defer { lock.unlock() }
        return lastErrorText
    }

    /// Called on the server's queue whenever the listener becomes ready, fails or stops.
    var onStateChange: (@Sendable (_ running: Bool, _ error: String?) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return stateHandler
        }
        set {
            lock.lock()
            stateHandler = newValue
            lock.unlock()
        }
    }

    /// Starts listening (no-op if already started). Throws if the listener cannot be created.
    func start() throws {
        try startListener(advertise: true)
    }

    func stop() {
        lock.lock()
        let current = listener
        listener = nil
        let wasRunning = running
        running = false
        let callback = stateHandler
        lock.unlock()

        current?.cancel()
        queue.async { [weak self] in
            self?.closeAllConnections()
        }
        if current != nil || wasRunning {
            Log.info("HTTP server stopped")
            callback?(false, nil)
        }
    }

    // MARK: Listener

    private func startListener(advertise: Bool) throws {
        guard listenPort != 0, let nwPort = NWEndpoint.Port(rawValue: listenPort) else {
            let message = "Invalid server port \(listenPort)."
            lock.lock()
            lastErrorText = message
            running = false
            let callback = stateHandler
            lock.unlock()
            callback?(false, message)
            throw HTTPServerError(message: message)
        }

        lock.lock()
        if listener != nil {
            lock.unlock()
            return
        }
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcp)
        parameters.allowLocalEndpointReuse = true

        let newListener: NWListener
        do {
            newListener = try NWListener(using: parameters, on: nwPort)
        } catch {
            let message = HTTPServer.describe(error, port: listenPort)
            lastErrorText = message
            running = false
            let callback = stateHandler
            lock.unlock()
            Log.error("HTTP server could not start: \(message)")
            callback?(false, message)
            throw HTTPServerError(message: message)
        }

        if advertise {
            newListener.service = NWListener.Service(name: SettingsStore.current.effectiveMacName,
                                                     type: EarshotAPI.bonjourType)
        }
        newListener.stateUpdateHandler = { [weak self, weak newListener] state in
            guard let self, let newListener else { return }
            self.listenerStateChanged(state, listener: newListener, advertising: advertise)
        }
        newListener.newConnectionHandler = { [weak self] connection in
            guard let self else {
                connection.cancel()
                return
            }
            self.accept(connection)
        }
        listener = newListener
        lastErrorText = nil
        lock.unlock()

        newListener.start(queue: queue)
    }

    /// Runs on `queue`.
    private func listenerStateChanged(_ state: NWListener.State, listener changed: NWListener, advertising: Bool) {
        var notification: (running: Bool, error: String?)?
        var retryWithoutBonjour = false

        lock.lock()
        guard listener === changed else {
            lock.unlock()
            return
        }
        switch state {
        case .ready:
            running = true
            lastErrorText = nil
            notification = (running: true, error: nil)
        case .waiting(let error):
            running = false
            lastErrorText = HTTPServer.describe(error, port: listenPort)
            notification = (running: false, error: lastErrorText)
            if advertising, case .dns = error {
                retryWithoutBonjour = true
                listener = nil
            }
        case .failed(let error):
            running = false
            listener = nil
            lastErrorText = HTTPServer.describe(error, port: listenPort)
            notification = (running: false, error: lastErrorText)
            if advertising, case .dns = error {
                retryWithoutBonjour = true
            }
        case .cancelled:
            running = false
            listener = nil
            notification = (running: false, error: lastErrorText)
        case .setup:
            break
        @unknown default:
            break
        }
        let callback = stateHandler
        let errorText = lastErrorText
        lock.unlock()

        if retryWithoutBonjour {
            changed.cancel()
            Log.error("Bonjour advertising failed (\(errorText ?? "unknown error")); restarting the server without Bonjour")
            do {
                try startListener(advertise: false)
            } catch {
                Log.error("HTTP server restart without Bonjour failed: \(error.localizedDescription)")
            }
            return
        }
        if case .failed = state {
            changed.cancel()
        }
        guard let notification else { return }
        if notification.running {
            let bonjour = advertising ? " and advertising \(EarshotAPI.bonjourType)" : ""
            Log.info("HTTP server listening on port \(listenPort)\(bonjour)")
        } else if let message = notification.error {
            Log.error("HTTP server is not running: \(message)")
        }
        callback?(notification.running, notification.error)
    }

    private static func describe(_ error: Error, port: UInt16) -> String {
        if let networkError = error as? NWError {
            if case .posix(let code) = networkError {
                switch code {
                case .EADDRINUSE:
                    return "Port \(port) is already in use by another app. Choose a different port in Settings."
                case .EACCES:
                    return "The app is not allowed to listen on port \(port)."
                default:
                    break
                }
            }
            return "Network error: \(String(describing: networkError))"
        }
        return error.localizedDescription
    }

    // MARK: Connections (all on `queue`)

    private func accept(_ connection: NWConnection) {
        let context = HTTPConnectionContext(connection: connection)
        let key = ObjectIdentifier(context)
        connections[key] = context
        connection.stateUpdateHandler = { [weak self, weak context] state in
            guard let self else { return }
            switch state {
            case .failed(let error):
                Log.debug("HTTP connection failed: \(String(describing: error))")
                if let context { self.close(context) }
            case .waiting(let error):
                Log.debug("HTTP connection stalled: \(String(describing: error))")
                if let context { self.close(context) }
            case .cancelled:
                self.connections.removeValue(forKey: key)
            default:
                break
            }
        }
        connection.start(queue: queue)
        scheduleIdleCheck(context, lastActivity: context.activity)
        receive(on: context)
    }

    private func receive(on context: HTTPConnectionContext) {
        context.connection.receive(minimumIncompleteLength: 1,
                                   maximumLength: HTTPServer.receiveChunk) { [weak self] data, _, isComplete, error in
            guard let self else {
                context.connection.cancel()
                return
            }
            self.handleReceive(context, data: data, isComplete: isComplete, error: error)
        }
    }

    private func handleReceive(_ context: HTTPConnectionContext, data: Data?, isComplete: Bool, error: NWError?) {
        guard !context.closed, !context.responding else { return }
        if let data, !data.isEmpty {
            context.buffer.append(data)
            context.activity &+= 1
        }
        if let error {
            Log.debug("HTTP receive error: \(String(describing: error))")
            close(context)
            return
        }

        switch evaluateHTTPBuffer(context.buffer) {
        case .complete(let request, _):
            context.responding = true
            context.buffer = Data()
            dispatch(request, on: context)
        case .reject(let status, let message):
            context.responding = true
            context.buffer = Data()
            Log.info("HTTP request rejected (\(status)): \(message)")
            send(HTTPResponse.error(status, message), on: context)
        case .needMore(let headerComplete, let expectsContinue):
            if isComplete {
                if !context.buffer.isEmpty {
                    Log.debug("HTTP client closed the connection before the request was complete")
                }
                close(context)
                return
            }
            if headerComplete && expectsContinue && !context.sentContinue {
                context.sentContinue = true
                context.connection.send(content: Data("HTTP/1.1 100 Continue\r\n\r\n".utf8),
                                        contentContext: .defaultMessage,
                                        isComplete: true,
                                        completion: .contentProcessed { _ in })
            }
            receive(on: context)
        }
    }

    private func dispatch(_ request: HTTPRequest, on context: HTTPConnectionContext) {
        let handler = self.handler
        let started = Date()
        Task(priority: .userInitiated) { [weak self] in
            let response = await handler(request)
            guard let self else {
                context.connection.cancel()
                return
            }
            self.queue.async {
                let elapsed = Int(Date().timeIntervalSince(started) * 1_000)
                Log.debug("HTTP \(request.method) \(request.path) → \(response.status) (\(elapsed) ms)")
                self.send(response, on: context)
            }
        }
    }

    private func send(_ response: HTTPResponse, on context: HTTPConnectionContext) {
        guard !context.closed else { return }
        let connection = context.connection
        let payload = HTTPParser.serialize(response)
        connection.send(content: payload,
                        contentContext: .defaultMessage,
                        isComplete: true,
                        completion: .contentProcessed { [weak self, weak context] error in
                            if let error {
                                Log.debug("HTTP send failed: \(String(describing: error))")
                            }
                            guard let self, let context else {
                                connection.cancel()
                                return
                            }
                            self.close(context)
                        })
    }

    private func close(_ context: HTTPConnectionContext) {
        if !context.closed {
            context.closed = true
            context.buffer = Data()
            context.connection.cancel()
        }
        connections.removeValue(forKey: ObjectIdentifier(context))
    }

    private func closeAllConnections() {
        let open = Array(connections.values)
        for context in open {
            close(context)
        }
    }

    /// Closes connections that stop sending data, and handlers that never finish.
    private func scheduleIdleCheck(_ context: HTTPConnectionContext, lastActivity: Int) {
        queue.asyncAfter(deadline: .now() + HTTPServer.idleTimeout) { [weak self, weak context] in
            guard let self, let context, !context.closed else { return }
            if context.responding {
                if Date().timeIntervalSince(context.openedAt) > HTTPServer.maxHandlerTime {
                    Log.error("HTTP handler did not finish within \(Int(HTTPServer.maxHandlerTime)) s; closing the connection")
                    self.close(context)
                } else {
                    self.scheduleIdleCheck(context, lastActivity: context.activity)
                }
                return
            }
            if context.activity == lastActivity {
                Log.debug("HTTP connection idle for \(Int(HTTPServer.idleTimeout)) s; closing")
                self.close(context)
            } else {
                self.scheduleIdleCheck(context, lastActivity: context.activity)
            }
        }
    }
}
