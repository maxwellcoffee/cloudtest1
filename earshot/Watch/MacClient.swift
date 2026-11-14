//  MacClient.swift
//  Earshot (watchOS)
//
//  HTTP client for the Mac companion (see Shared/EarshotProtocol.swift).
//  Uses a normal (foreground) URLSession: while the watch records, the app keeps
//  running, and background URLSession transfers can be deferred for hours.

import Foundation
import WatchKit

/// Errors surfaced by `MacClient`.
enum MacClientError: LocalizedError, Equatable {
    /// No base URL or no token yet.
    case notPaired
    /// The Mac rejected the token (HTTP 401) — the watch must pair again.
    case unauthorized
    /// Any other non-2xx status, with the server's message when it sent one.
    case http(Int, String?)
    /// The address the user typed cannot be turned into a URL.
    case invalidURL
    /// The reply was not an HTTP response.
    case invalidResponse
    /// The body could not be decoded.
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notPaired:
            return "This watch isn't paired with a Mac yet."
        case .unauthorized:
            return "Your Mac no longer recognises this watch. Pair again."
        case .http(let status, let message):
            if let message, !message.isEmpty { return "Mac error \(status): \(message)" }
            return "Mac error \(status)."
        case .invalidURL:
            return "That Mac address isn't valid."
        case .invalidResponse:
            return "Unexpected reply from the Mac."
        case .decoding(let detail):
            return "Couldn't read the Mac's reply (\(detail))."
        }
    }
}

@MainActor
final class MacClient {
    /// Base URL of the Mac, e.g. http://192.168.1.5:8737 (no trailing slash needed).
    private(set) var baseURL: URL?
    /// Bearer token from pairing.
    var token: String?

    var isPaired: Bool {
        guard baseURL != nil, let token else { return false }
        return !token.isEmpty
    }

    private let session: URLSession
    private let uploadSession: URLSession

    init() {
        let standard = URLSessionConfiguration.default
        standard.timeoutIntervalForRequest = 20
        standard.timeoutIntervalForResource = 60
        standard.waitsForConnectivity = false
        standard.requestCachePolicy = .reloadIgnoringLocalCacheData
        standard.urlCache = nil
        session = URLSession(configuration: standard)

        let uploads = URLSessionConfiguration.default
        uploads.timeoutIntervalForRequest = 120
        uploads.timeoutIntervalForResource = 600
        uploads.waitsForConnectivity = false
        uploads.requestCachePolicy = .reloadIgnoringLocalCacheData
        uploads.urlCache = nil
        uploadSession = URLSession(configuration: uploads)
    }

    func setBaseURL(_ url: URL?) {
        baseURL = url
    }

    // MARK: - Address parsing

    /// Turns what the user typed into a base URL.
    /// "192.168.1.5" → http://192.168.1.5:8737, "mac.local:8737" → http://mac.local:8737,
    /// "[fe80::1]:8737" or "fe80::1" → IPv6, full http(s) URLs are used as they are.
    nonisolated static func baseURL(from input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") { text.removeLast() }
        guard !text.isEmpty, !text.contains(" ") else { return nil }

        let lower = text.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            guard let url = URL(string: text), let host = url.host, !host.isEmpty else { return nil }
            return url
        }
        guard !text.contains("/") else { return nil }

        let defaultPort = Int(EarshotAPI.defaultPort)
        var host = text
        var port = defaultPort

        if text.hasPrefix("[") {
            // Bracketed IPv6, optionally with a port: [fe80::1]:8737
            guard let close = text.firstIndex(of: "]") else { return nil }
            host = String(text[text.index(after: text.startIndex)..<close])
            let rest = text[text.index(after: close)...]
            if rest.hasPrefix(":") {
                guard let parsed = Int(rest.dropFirst()), (1...65_535).contains(parsed) else { return nil }
                port = parsed
            } else if !rest.isEmpty {
                return nil
            }
        } else {
            let parts = text.split(separator: ":", omittingEmptySubsequences: false)
            if parts.count == 2 {
                host = String(parts[0])
                guard let parsed = Int(parts[1]), (1...65_535).contains(parsed) else { return nil }
                port = parsed
            } else if parts.count > 2 {
                host = text   // bare IPv6 literal
            }
        }

        guard !host.isEmpty else { return nil }
        let hostPart = host.contains(":") ? "[\(host)]" : host
        return URL(string: "http://\(hostPart):\(port)")
    }

    // MARK: - Endpoints

    /// GET /hello — no auth. `baseURL` overrides the stored address (used while pairing).
    func hello(baseURL override: URL? = nil) async throws -> ServerHello {
        let request = try makeRequest(EarshotAPI.Path.hello, method: "GET", base: override,
                                      authenticated: false, timeout: 15)
        return try await perform(request, as: ServerHello.self)
    }

    /// POST /pair — no auth.
    func pair(code: String, baseURL override: URL? = nil) async throws -> PairResponse {
        let body = PairRequest(code: code, deviceName: WKInterfaceDevice.current().name, deviceKind: "watch")
        var request = try makeRequest(EarshotAPI.Path.pair, method: "POST", base: override,
                                      authenticated: false, timeout: 20)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encode(body)
        return try await perform(request, as: PairResponse.self)
    }

    /// POST /segments — streams the .m4a straight from disk with SegmentMeta headers.
    func uploadSegment(fileURL: URL, meta: SegmentMeta) async throws -> SegmentAck {
        var request = try makeRequest(EarshotAPI.Path.segments, method: "POST", base: nil,
                                      authenticated: true, timeout: 120)
        for (name, value) in meta.headerFields() {
            request.setValue(value, forHTTPHeaderField: name)
        }
        request.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await uploadSession.upload(for: request, fromFile: fileURL)
        try validate(data, response)
        return try decode(SegmentAck.self, from: data)
    }

    /// POST /sync — status up, prompts/today/settings down.
    func sync(_ report: WatchStatusReport) async throws -> SyncResponse {
        try await postJSON(EarshotAPI.Path.sync, report, as: SyncResponse.self)
    }

    /// POST /answers
    func send(answer: PromptAnswer) async throws {
        _ = try await postJSON(EarshotAPI.Path.answers, answer, as: OKResponse.self)
    }

    /// POST /requests
    func send(request: WatchRequest) async throws -> WatchRequestAck {
        try await postJSON(EarshotAPI.Path.requests, request, as: WatchRequestAck.self)
    }

    /// POST /bookmarks
    func send(bookmark: Bookmark) async throws {
        _ = try await postJSON(EarshotAPI.Path.bookmarks, bookmark, as: OKResponse.self)
    }

    // MARK: - Error helpers

    /// Network trouble and server-side failures are worth retrying later;
    /// other 4xx answers will never succeed as they are.
    nonisolated static func isTransient(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if error is URLError { return true }
        if let clientError = error as? MacClientError {
            switch clientError {
            case .http(let status, _):
                return status >= 500 || status == 408 || status == 429
            case .invalidResponse:
                return true
            case .notPaired, .unauthorized, .invalidURL, .decoding:
                return false
            }
        }
        return (error as NSError).domain == NSURLErrorDomain
    }

    /// Short, user-facing description of an error.
    nonisolated static func describe(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "No network connection"
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .timedOut:
                return "Mac not reachable"
            case .appTransportSecurityRequiresSecureConnection:
                return "Blocked by App Transport Security"
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
                 .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot:
                return "Secure connection failed"
            case .cancelled:
                return "Cancelled"
            default:
                return urlError.localizedDescription
            }
        }
        if let clientError = error as? MacClientError {
            return clientError.errorDescription ?? "Mac error"
        }
        if error is CancellationError { return "Cancelled" }
        return error.localizedDescription
    }

    // MARK: - Plumbing

    private func makeRequest(_ path: String, method: String, base override: URL?,
                             authenticated: Bool, timeout: TimeInterval) throws -> URLRequest {
        guard let base = override ?? baseURL else { throw MacClientError.notPaired }
        guard let url = Self.endpoint(base, path) else { throw MacClientError.invalidURL }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authenticated {
            guard let token, !token.isEmpty else { throw MacClientError.notPaired }
            request.setValue("Bearer \(token)", forHTTPHeaderField: EarshotAPI.Header.authorization)
        }
        return request
    }

    private nonisolated static func endpoint(_ base: URL, _ path: String) -> URL? {
        var text = base.absoluteString
        while text.hasSuffix("/") { text.removeLast() }
        return URL(string: text + path)
    }

    private func postJSON<Body: Encodable, Response: Decodable>(_ path: String, _ body: Body,
                                                                as type: Response.Type) async throws -> Response {
        var request = try makeRequest(path, method: "POST", base: nil, authenticated: true, timeout: 20)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encode(body)
        return try await perform(request, as: type)
    }

    private func perform<Response: Decodable>(_ request: URLRequest, as type: Response.Type) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        try validate(data, response)
        return try decode(type, from: data)
    }

    private func validate(_ data: Data, _ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw MacClientError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            return
        case 401:
            throw MacClientError.unauthorized
        default:
            let message = (try? EarshotAPI.makeDecoder().decode(APIErrorBody.self, from: data))?.error
            throw MacClientError.http(http.statusCode, message)
        }
    }

    private func encode<Body: Encodable>(_ body: Body) throws -> Data {
        try EarshotAPI.makeEncoder().encode(body)
    }

    private func decode<Response: Decodable>(_ type: Response.Type, from data: Data) throws -> Response {
        do {
            return try EarshotAPI.makeDecoder().decode(type, from: data)
        } catch {
            throw MacClientError.decoding(Self.decodingDetail(error))
        }
    }

    private nonisolated static func decodingDetail(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else { return error.localizedDescription }
        switch decodingError {
        case .keyNotFound(let key, _):
            return "missing \(key.stringValue)"
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? context.debugDescription : "bad \(path)"
        @unknown default:
            return "invalid JSON"
        }
    }
}
