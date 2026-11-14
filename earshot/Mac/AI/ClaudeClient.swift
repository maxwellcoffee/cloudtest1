//  ClaudeClient.swift
//  Minimal raw-HTTP client for the Anthropic Messages API (POST /v1/messages).
//  Swift has no official Anthropic SDK, so requests are built as JSON trees.
//
//  - Assistant content is kept as JSONValue and must be appended back to the
//    conversation unchanged (thinking blocks, tool_use blocks, toolset_name...).
//  - For models that support it, server-side refusal fallbacks are enabled
//    (`fallbacks: "default"` + beta header) so a classifier false positive does
//    not break the always-on pipeline.

import Foundation

struct ClaudeToolUse: Hashable, Sendable {
    let id: String
    let name: String
    /// "computer" for members of the computer use toolset, nil for custom tools.
    let toolsetName: String?
    let input: JSONValue
}

struct ClaudeResponse: Sendable {
    let raw: JSONValue

    var content: [JSONValue] { raw["content"]?.arrayValue ?? [] }
    var stopReason: String? { raw["stop_reason"]?.stringValue }
    var model: String? { raw["model"]?.stringValue }
    var refusalCategory: String? { raw["stop_details"]?["category"]?.stringValue }

    /// All text blocks joined.
    var text: String {
        content.compactMap { block -> String? in
            guard block["type"]?.stringValue == "text" else { return nil }
            return block["text"]?.stringValue
        }.joined(separator: "\n")
    }

    /// Non-empty thinking-block texts (progress updates / summaries, if enabled).
    var thinkingNotes: [String] {
        content.compactMap { block -> String? in
            guard block["type"]?.stringValue == "thinking",
                  let t = block["thinking"]?.stringValue, !t.trimmed.isEmpty else { return nil }
            return t
        }
    }

    var toolUses: [ClaudeToolUse] {
        content.compactMap { block -> ClaudeToolUse? in
            guard block["type"]?.stringValue == "tool_use",
                  let id = block["id"]?.stringValue,
                  let name = block["name"]?.stringValue else { return nil }
            return ClaudeToolUse(id: id, name: name, toolsetName: block["toolset_name"]?.stringValue,
                                 input: block["input"] ?? .object([:]))
        }
    }

    /// The assistant turn to append to the message history verbatim.
    var assistantMessage: JSONValue {
        .object(["role": "assistant", "content": .array(content)])
    }

    var inputTokens: Int { raw["usage"]?["input_tokens"]?.intValue ?? 0 }
    var outputTokens: Int { raw["usage"]?["output_tokens"]?.intValue ?? 0 }
}

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case http(status: Int, type: String, message: String)
    case refusal(category: String?)
    case truncated
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Anthropic API key. Add one in Settings → AI."
        case .http(let status, let type, let message):
            return "Claude API error \(status) (\(type)): \(message)"
        case .refusal(let category):
            return "Claude declined this request" + (category.map { " (\($0))" } ?? "") + "."
        case .truncated:
            return "Claude's reply was cut off (max_tokens)."
        case .invalidResponse(let detail):
            return "Unexpected Claude API response: \(detail)"
        }
    }
}

final class ClaudeClient: @unchecked Sendable {
    static let apiVersion = "2026-10-21"
    static let fallbackBeta = "server-side-fallback-2026-07-01"

    static let defaultTimeout: TimeInterval = 600

    /// One URLSession (and connection pool) shared by every client that uses the default
    /// timeout. Clients are created per agent run and whenever the key changes, so a
    /// session per instance would pile up sessions that are never invalidated.
    private static let sharedSession: URLSession = makeSession(timeout: defaultTimeout)

    private static func makeSession(timeout: TimeInterval) -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        return URLSession(configuration: config)
    }

    let apiKey: String
    let baseURL: URL
    private let session: URLSession
    /// True when this client created its own session (non-default timeout) and must invalidate it.
    private let ownsSession: Bool

    init(apiKey: String, baseURL: URL = URL(string: "https://api.anthropic.com")!, timeout: TimeInterval = 600) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        if timeout == ClaudeClient.defaultTimeout {
            self.session = ClaudeClient.sharedSession
            self.ownsSession = false
        } else {
            self.session = ClaudeClient.makeSession(timeout: timeout)
            self.ownsSession = true
        }
    }

    deinit {
        // Lets any in-flight task finish, then releases the session's resources.
        if ownsSession { session.finishTasksAndInvalidate() }
    }

    /// Client using the key from Settings / Keychain / ANTHROPIC_API_KEY.
    static func fromSettings() throws -> ClaudeClient {
        let key = SettingsStore.anthropicKey
        guard !key.trimmed.isEmpty else { throw ClaudeError.missingAPIKey }
        return ClaudeClient(apiKey: key.trimmed)
    }

    // MARK: Request building

    /// Models that accept the server-side `fallbacks` parameter.
    static func supportsServerFallback(_ model: String) -> Bool {
        ["claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5", "claude-fable-5-2", "claude-fable-5-1"].contains(model)
    }

    /// Builds a Messages API body.
    /// - effort: "low" | "medium" | "high" | "xhigh" | "max" (nil = model default)
    /// - jsonSchema: when set, the reply is constrained to this JSON Schema (structured outputs).
    /// - thinkingDisplay: e.g. "summarized" to get readable thinking summaries.
    /// Returns the body plus the beta headers it needs.
    static func makeBody(model: String,
                         system: String?,
                         messages: [JSONValue],
                         maxTokens: Int = 16_000,
                         effort: String? = nil,
                         tools: [JSONValue]? = nil,
                         jsonSchema: JSONValue? = nil,
                         thinkingDisplay: String? = nil) -> (body: JSONValue, betas: [String]) {
        var o: [String: JSONValue] = [
            "model": .string(model),
            "max_tokens": .number(Double(maxTokens)),
            "messages": .array(messages),
        ]
        if let system, !system.isEmpty {
            // A system prompt block with a cache breakpoint: the stable prefix is reused across calls.
            o["system"] = .array([.object([
                "type": "text",
                "text": .string(system),
                "cache_control": .object(["type": "ephemeral"]),
            ])])
        }
        var outputConfig: [String: JSONValue] = [:]
        if let effort, !effort.isEmpty { outputConfig["effort"] = .string(effort) }
        if let jsonSchema {
            outputConfig["format"] = .object(["type": "json_schema", "schema": jsonSchema])
        }
        if !outputConfig.isEmpty { o["output_config"] = .object(outputConfig) }
        if let tools, !tools.isEmpty { o["tools"] = .array(tools) }
        if let thinkingDisplay {
            o["thinking"] = .object(["type": "adaptive", "display": .string(thinkingDisplay)])
        }
        var betas: [String] = []
        if supportsServerFallback(model) {
            o["fallbacks"] = "default"
            betas.append(fallbackBeta)
        }
        return (.object(o), betas)
    }

    static func userMessage(_ text: String) -> JSONValue {
        .object(["role": "user", "content": .array([textBlock(text)])])
    }

    static func userMessage(content: [JSONValue]) -> JSONValue {
        .object(["role": "user", "content": .array(content)])
    }

    static func textBlock(_ text: String) -> JSONValue {
        .object(["type": "text", "text": .string(text)])
    }

    static func imageBlock(pngData: Data) -> JSONValue {
        .object([
            "type": "image",
            "source": .object([
                "type": "base64",
                "media_type": "image/png",
                "data": .string(pngData.base64EncodedString()),
            ]),
        ])
    }

    /// A tool_result block. Pass `toolsetName: "computer"` for computer-toolset members
    /// (the API rejects results that omit it).
    static func toolResult(toolUseID: String, content: [JSONValue], isError: Bool = false,
                           toolsetName: String? = nil) -> JSONValue {
        var o: [String: JSONValue] = [
            "type": "tool_result",
            "tool_use_id": .string(toolUseID),
            "content": .array(content),
        ]
        if isError { o["is_error"] = true }
        if let toolsetName { o["toolset_name"] = .string(toolsetName) }
        return .object(o)
    }

    static func toolResult(toolUseID: String, text: String, isError: Bool = false,
                           toolsetName: String? = nil) -> JSONValue {
        toolResult(toolUseID: toolUseID, content: [textBlock(text.isEmpty ? "OK" : text)],
                   isError: isError, toolsetName: toolsetName)
    }

    // MARK: Sending

    /// POST /v1/messages. Retries 408/409/429/5xx/529 and connection errors with backoff.
    /// Throws `ClaudeError.refusal` when the whole fallback chain declined.
    func createMessage(_ body: JSONValue, betas: [String] = []) async throws -> ClaudeResponse {
        var currentBody = body
        var currentBetas = betas
        var attempt = 0
        var strippedFallbacks = false
        while true {
            attempt += 1
            do {
                let (data, http) = try await post(currentBody, betas: currentBetas)
                if (200..<300).contains(http.statusCode) {
                    let json: JSONValue
                    do { json = try JSONValue.parse(data) } catch {
                        throw ClaudeError.invalidResponse("not JSON")
                    }
                    let response = ClaudeResponse(raw: json)
                    if response.stopReason == "refusal" {
                        throw ClaudeError.refusal(category: response.refusalCategory)
                    }
                    return response
                }
                let errJSON = try? JSONValue.parse(data)
                let type = errJSON?["error"]?["type"]?.stringValue ?? "error"
                let message = errJSON?["error"]?["message"]?.stringValue
                    ?? String(decoding: data.prefix(500), as: UTF8.self)
                // If this account/platform rejects the fallbacks parameter, retry once without it.
                if http.statusCode == 400, !strippedFallbacks, message.lowercased().contains("fallback"),
                   case .object(var o) = currentBody {
                    o.removeValue(forKey: "fallbacks")
                    currentBody = .object(o)
                    currentBetas.removeAll { $0 == ClaudeClient.fallbackBeta }
                    strippedFallbacks = true
                    attempt -= 1
                    continue
                }
                let retryable = [408, 409, 429, 500, 502, 503, 504, 529].contains(http.statusCode)
                if retryable && attempt < 4 {
                    let retryAfter = Double(http.value(forHTTPHeaderField: "retry-after") ?? "") ?? 0
                    let delay = max(retryAfter, pow(2.0, Double(attempt)))
                    try await Task.sleep(nanoseconds: UInt64(min(delay, 60) * 1_000_000_000))
                    continue
                }
                throw ClaudeError.http(status: http.statusCode, type: type, message: message)
            } catch let error as URLError where attempt < 4 && error.code != .cancelled {
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                continue
            }
        }
    }

    private func post(_ body: JSONValue, betas: [String]) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/messages"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(ClaudeClient.apiVersion, forHTTPHeaderField: "anthropic-version")
        if !betas.isEmpty {
            request.setValue(betas.joined(separator: ","), forHTTPHeaderField: "anthropic-beta")
        }
        request.httpBody = try body.encodedData()
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse("no HTTP response")
        }
        return (data, http)
    }

    // MARK: Conveniences

    /// One-shot text completion.
    func complete(model: String, system: String, user: String, maxTokens: Int = 16_000,
                  effort: String? = nil) async throws -> String {
        let built = ClaudeClient.makeBody(model: model, system: system, messages: [ClaudeClient.userMessage(user)],
                                          maxTokens: maxTokens, effort: effort)
        let response = try await createMessage(built.body, betas: built.betas)
        if response.stopReason == "max_tokens" && response.text.isEmpty { throw ClaudeError.truncated }
        return response.text
    }

    /// One-shot completion constrained to `schema`; returns the parsed JSON object.
    func completeJSON(model: String, system: String, user: String, schema: JSONValue,
                      maxTokens: Int = 16_000, effort: String? = nil) async throws -> JSONValue {
        let built = ClaudeClient.makeBody(model: model, system: system, messages: [ClaudeClient.userMessage(user)],
                                          maxTokens: maxTokens, effort: effort, jsonSchema: schema)
        let response = try await createMessage(built.body, betas: built.betas)
        if response.stopReason == "max_tokens" { throw ClaudeError.truncated }
        let text = response.text.trimmed
        guard !text.isEmpty else { throw ClaudeError.invalidResponse("empty structured output") }
        do {
            return try JSONValue.parse(text)
        } catch {
            throw ClaudeError.invalidResponse("structured output was not valid JSON")
        }
    }
}
