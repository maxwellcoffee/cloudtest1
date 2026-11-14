//  LLM.swift
//  One entry point for every model call in the app. Routes to Claude (tiered
//  model + effort) or to Apple's on-device Foundation Models when the user
//  chose the private, offline backend.

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum LLMTier: Sendable {
    /// Frequent, cheaper work: transcript extraction, chunk summaries, search planning.
    case background
    /// User-facing work: digests, memory answers, answer interpretation.
    case foreground
}

private enum LLMServiceError: LocalizedError {
    case onDeviceUnavailable(String)
    case onDeviceFailed(String)
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .onDeviceUnavailable(let reason):
            return "The Apple on-device model is unavailable (\(reason)) and no Anthropic API key is set. Add a key in Settings → AI or switch the AI backend to Claude."
        case .onDeviceFailed(let detail):
            return "The Apple on-device model could not answer: \(detail)"
        case .invalidJSON(let detail):
            return "The on-device model's reply could not be read as JSON (\(detail))."
        }
    }
}

final class LLMService: @unchecked Sendable {
    static let shared = LLMService()

    private let lock = NSLock()
    private var cachedClient: ClaudeClient?

    private static let defaultModel = "claude-opus-5-5"
    private static let validEfforts: Set<String> = ["low", "medium", "high", "xhigh", "max"]
    /// Upper bound when a reply hits max_tokens and is retried with a larger budget.
    private static let maxRetryTokens = 32_000
    /// The on-device model has a small context window (about 4K tokens) shared by input and output.
    private static let onDeviceInstructionBudget = 4_000
    private static let onDevicePromptBudget = 6_000

    init() {}

    // MARK: Status

    /// Claude key present, or the on-device model selected and available.
    var isConfigured: Bool {
        if SettingsStore.current.llmBackend == .appleOnDevice, LLMService.onDeviceStatus().available {
            return true
        }
        return LLMService.hasClaudeKey
    }

    /// e.g. "Claude · claude-opus-5-5" or "Apple on-device model".
    var backendDescription: String {
        let settings = SettingsStore.current
        let foreground = LLMService.foregroundModel(settings)
        let background = LLMService.backgroundModel(settings)
        let claude = background == foreground
            ? "Claude · \(foreground)"
            : "Claude · \(foreground) (background: \(background))"
        switch settings.llmBackend {
        case .claude:
            return LLMService.hasClaudeKey ? claude : "Claude · no API key (add one in Settings → AI)"
        case .appleOnDevice:
            let status = LLMService.onDeviceStatus()
            if status.available { return "Apple on-device model" }
            if LLMService.hasClaudeKey { return "\(claude), on-device model unavailable (\(status.reason))" }
            return "Apple on-device model unavailable (\(status.reason))"
        }
    }

    // MARK: Completions

    func complete(system: String, user: String, tier: LLMTier, maxTokens: Int) async throws -> String {
        let settings = SettingsStore.current
        if try useOnDevice(settings) {
            return try await onDeviceRespond(instructions: system, prompt: user, suffix: "")
        }
        let client = try claudeClient()
        let route = LLMService.route(tier, settings)
        let cloud = LLMService.cloudText(system: system, user: user, settings)
        var tokens = max(1_024, maxTokens)
        while true {
            do {
                return try await client.complete(model: route.model, system: cloud.system, user: cloud.user,
                                                 maxTokens: tokens, effort: route.effort)
            } catch ClaudeError.truncated where tokens < LLMService.maxRetryTokens {
                let larger = min(tokens * 2, LLMService.maxRetryTokens)
                Log.info("LLM: reply hit max_tokens (\(tokens)); retrying with \(larger).")
                tokens = larger
            }
        }
    }

    func completeJSON(system: String, user: String, schema: JSONValue, tier: LLMTier, maxTokens: Int) async throws -> JSONValue {
        let settings = SettingsStore.current
        if try useOnDevice(settings) {
            return try await onDeviceJSON(system: system, user: user, schema: schema)
        }
        let client = try claudeClient()
        let route = LLMService.route(tier, settings)
        let cloud = LLMService.cloudText(system: system, user: user, settings)
        var tokens = max(1_024, maxTokens)
        while true {
            do {
                return try await client.completeJSON(model: route.model, system: cloud.system, user: cloud.user,
                                                     schema: schema, maxTokens: tokens, effort: route.effort)
            } catch ClaudeError.truncated where tokens < LLMService.maxRetryTokens {
                let larger = min(tokens * 2, LLMService.maxRetryTokens)
                Log.info("LLM: structured reply hit max_tokens (\(tokens)); retrying with \(larger).")
                tokens = larger
            }
        }
    }

    // MARK: Claude routing

    private static var hasClaudeKey: Bool { !SettingsStore.anthropicKey.trimmed.isEmpty }

    /// The text actually sent to Claude: with `redactBeforeCloud`, e-mail addresses, phone, card,
    /// account and Social Security numbers and one-time codes are replaced locally with placeholders.
    /// Deterministic, so the cached system-prompt prefix stays identical. Never used on-device.
    private static func cloudText(system: String, user: String, _ settings: AppSettings) -> (system: String, user: String) {
        guard settings.redactBeforeCloud else { return (system, user) }
        return (Redactor.redact(system), Redactor.redact(user))
    }

    private func claudeClient() throws -> ClaudeClient {
        let key = SettingsStore.anthropicKey.trimmed
        guard !key.isEmpty else { throw ClaudeError.missingAPIKey }
        lock.lock()
        defer { lock.unlock() }
        if let client = cachedClient, client.apiKey == key { return client }
        let client = try ClaudeClient.fromSettings()
        cachedClient = client
        return client
    }

    private static func foregroundModel(_ settings: AppSettings) -> String {
        settings.claudeModel.nilIfEmpty ?? defaultModel
    }

    private static func backgroundModel(_ settings: AppSettings) -> String {
        settings.claudeBackgroundModel.nilIfEmpty ?? foregroundModel(settings)
    }

    private static func route(_ tier: LLMTier, _ settings: AppSettings) -> (model: String, effort: String?) {
        let model: String
        let effort: String?
        switch tier {
        case .background:
            model = backgroundModel(settings)
            let requested = settings.backgroundEffort.trimmed.lowercased()
            effort = validEfforts.contains(requested) ? requested : nil
        case .foreground:
            model = foregroundModel(settings)
            effort = "high"
        }
        return (model, supportsEffort(model) ? effort : nil)
    }

    /// Older models reject `output_config.effort`.
    private static func supportsEffort(_ model: String) -> Bool {
        let m = model.lowercased()
        let unsupported = ["claude-3", "haiku-4", "sonnet-4-5", "sonnet-4-2", "opus-4-1", "opus-4-2"]
        return !unsupported.contains(where: { m.contains($0) })
    }

    // MARK: On-device (Apple Foundation Models)

    /// True when the on-device model should answer. Throws when it was chosen but is unavailable
    /// and Claude cannot stand in (no key).
    private func useOnDevice(_ settings: AppSettings) throws -> Bool {
        guard settings.llmBackend == .appleOnDevice else { return false }
        let status = LLMService.onDeviceStatus()
        if status.available { return true }
        guard LLMService.hasClaudeKey else { throw LLMServiceError.onDeviceUnavailable(status.reason) }
        Log.info("LLM: Apple on-device model unavailable (\(status.reason)); falling back to Claude.")
        return false
    }

    private static func onDeviceStatus() -> (available: Bool, reason: String) {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            if model.isAvailable { return (true, "ready") }
            if case .unavailable(let reason) = model.availability {
                switch reason {
                case .deviceNotEligible:
                    return (false, "this Mac does not support Apple Intelligence")
                case .appleIntelligenceNotEnabled:
                    return (false, "Apple Intelligence is turned off in System Settings")
                case .modelNotReady:
                    return (false, "the model is still being prepared")
                @unknown default:
                    return (false, "not available")
                }
            }
            return (false, "not available")
        }
        return (false, "requires macOS 26 or later")
        #else
        return (false, "not supported by this build")
        #endif
    }

    /// Runs one prompt on the on-device model. `prompt` is trimmed to fit the small context
    /// window; `suffix` (e.g. the JSON shape) is always kept intact.
    private func onDeviceRespond(instructions: String, prompt: String, suffix: String) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let compact = LLMService.clip(LLMService.onDeviceInstructions(instructions),
                                          to: LLMService.onDeviceInstructionBudget)
            var budget = LLMService.onDevicePromptBudget
            var lastFailure = "unknown error"
            for attempt in 1...2 {
                let session = LanguageModelSession(instructions: compact)
                let fullPrompt = LLMService.clip(prompt, to: budget) + suffix
                do {
                    let response = try await session.respond(to: fullPrompt)
                    return response.content
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    // Any failure (GenerationError when built with Xcode 26; LanguageModelError and
                    // friends with Xcode 27+): retry once with a shorter prompt, then report it.
                    lastFailure = error.localizedDescription
                    Log.error("LLM: on-device generation failed (attempt \(attempt)): \(lastFailure)")
                    budget /= 2
                }
            }
            throw LLMServiceError.onDeviceFailed(lastFailure)
        }
        #endif
        throw LLMServiceError.onDeviceUnavailable("requires macOS 26 with Apple Intelligence")
    }

    private func onDeviceJSON(system: String, user: String, schema: JSONValue) async throws -> JSONValue {
        let suffix = "\n\nReply with a single JSON object of exactly this shape (every key is required; use \"\" or [] when unknown):\n"
            + LLMService.describeSchema(schema)
            + "\nReply with only JSON: no prose, no code fences."
        var lastError: Error = LLMServiceError.invalidJSON("no reply")
        for attempt in 1...2 {
            let reply = try await onDeviceRespond(instructions: system, prompt: user, suffix: suffix)
            do {
                return try LLMService.extractJSONObject(reply)
            } catch {
                lastError = error
                Log.error("LLM: on-device reply was not valid JSON (attempt \(attempt), \(reply.count) characters).")
            }
        }
        throw lastError
    }

    /// Swaps the long persona for the compact one; the task instructions are kept.
    private static func onDeviceInstructions(_ system: String) -> String {
        let persona = PromptLibrary.companionPersona
        guard system.hasPrefix(persona) else { return system }
        return PromptLibrary.compactPersona + String(system.dropFirst(persona.count))
    }

    /// Keeps the head and the tail of over-long text (the tail usually holds the newest transcript).
    private static func clip(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        guard limit > 400 else { return String(text.suffix(max(0, limit))) }
        let marker = "\n…[trimmed to fit the on-device model]…\n"
        let head = limit / 3
        let tail = max(0, limit - head - marker.count)
        return String(text.prefix(head)) + marker + String(text.suffix(tail))
    }

    /// Compact, JSON-like description of a JSON Schema for models without structured outputs.
    private static func describeSchema(_ schema: JSONValue) -> String {
        switch schema["type"]?.stringValue ?? "" {
        case "object":
            let properties = schema["properties"]?.objectValue ?? [:]
            var order = (schema["required"]?.arrayValue ?? []).compactMap { $0.stringValue }
            for key in properties.keys.sorted() where !order.contains(key) { order.append(key) }
            let fields = order.compactMap { key -> String? in
                guard let sub = properties[key] else { return nil }
                return "\"\(key)\": \(describeSchema(sub))"
            }
            return "{" + fields.joined(separator: ", ") + "}"
        case "array":
            return "[" + describeSchema(schema["items"] ?? .object([:])) + ", ...]"
        case "string":
            let values = (schema["enum"]?.arrayValue ?? []).compactMap { $0.stringValue }
            if !values.isEmpty { return values.map { "\"\($0)\"" }.joined(separator: " | ") }
            return "string"
        case "integer":
            return "integer"
        case "number":
            return "number"
        case "boolean":
            return "true | false"
        default:
            return "any"
        }
    }

    /// Parses the outermost {...} of a reply (tolerates prose or code fences around it).
    private static func extractJSONObject(_ text: String) throws -> JSONValue {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            throw LLMServiceError.invalidJSON("no JSON object in the reply")
        }
        let candidate = String(text[start...end])
        let value: JSONValue
        do {
            value = try JSONValue.parse(candidate)
        } catch {
            throw LLMServiceError.invalidJSON("malformed JSON")
        }
        guard value.objectValue != nil else { throw LLMServiceError.invalidJSON("not a JSON object") }
        return value
    }
}
