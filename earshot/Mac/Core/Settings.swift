//  Settings.swift
//  User preferences. `AppSettings` is a plain value (safe to read from any
//  thread via `SettingsStore.current`); secrets live in the Keychain.

import Foundation
import Security
import Combine

enum TranscriptionEngine: String, Codable, CaseIterable, Identifiable, Sendable {
    case speechAnalyzer   // Apple SpeechAnalyzer (macOS 26+), on-device
    case appleSpeech      // Apple SFSpeechRecognizer, on-device when supported
    case whisperAPI       // OpenAI-compatible /audio/transcriptions endpoint
    var id: String { rawValue }
    var label: String {
        switch self {
        case .speechAnalyzer: return "Apple SpeechAnalyzer (on-device, macOS 26+)"
        case .appleSpeech: return "Apple Speech (SFSpeechRecognizer)"
        case .whisperAPI: return "Whisper-compatible API"
        }
    }
}

enum LLMBackend: String, Codable, CaseIterable, Identifiable, Sendable {
    case claude          // Anthropic Claude API
    case appleOnDevice   // Apple Foundation Models (macOS 26+, Apple Intelligence)
    var id: String { rawValue }
    var label: String {
        switch self {
        case .claude: return "Claude (Anthropic API)"
        case .appleOnDevice: return "Apple on-device model (private, offline)"
        }
    }
}

struct AppSettings: Codable, Hashable, Sendable {
    // About you — fed to every AI prompt so insights and questions are personal.
    var userName: String = ""
    var aboutMe: String = ""
    var lifeGoals: String = ""

    // AI
    var llmBackend: LLMBackend = .claude
    /// Model for the agent, digests and memory chat.
    var claudeModel: String = "claude-opus-5-5"
    /// Model for frequent background extraction from the transcript.
    var claudeBackgroundModel: String = "claude-opus-5-5"
    /// "low" | "medium" | "high" | "xhigh" | "max"
    var backgroundEffort: String = "medium"
    var agentEffort: String = "high"

    // Transcription
    var transcriptionEngine: TranscriptionEngine = .speechAnalyzer
    var localeIdentifier: String = "en-US"
    var whisperBaseURL: String = "https://api.openai.com/v1"
    var whisperModel: String = "whisper-1"

    // Server
    var serverPort: Int = Int(EarshotAPI.defaultPort)
    /// Name shown to the watch. Empty = use the computer's host name.
    var macDisplayName: String = ""

    // Recording (pushed to the watch on every sync)
    var segmentSeconds: Int = 120
    var silenceThresholdDB: Float = -45
    var skipSilentSegments: Bool = true
    var lowBatteryStopLevel: Float = 0.10
    /// Delete raw audio after this many days (transcripts are kept). 0 = delete right after transcription.
    var keepAudioDays: Int = 7

    // Insights
    /// Analyse the transcript every N minutes (if there is new speech).
    var analysisIntervalMinutes: Int = 15
    /// Minimum new words before an analysis pass runs.
    var analysisMinWords: Int = 120

    // Proactive questions
    var questionsEnabled: Bool = true
    var maxQuestionsPerDay: Int = 6
    var minMinutesBetweenQuestions: Int = 75
    var quietHoursStart: Int = 21   // 24h clock, local
    var quietHoursEnd: Int = 8
    var avoidQuestionsDuringConversation: Bool = true
    var avoidQuestionsDuringMeetings: Bool = true

    // Digest
    var dailyDigestHour: Int = 21
    var weeklyReviewWeekday: Int = 1   // 1 = Sunday (Calendar weekday numbering)

    // Actions & agent
    var autoApproveLowRisk: Bool = true
    var autoApproveMediumRisk: Bool = false
    var computerUseEnabled: Bool = false
    var agentMaxSteps: Int = 40
    var notesFolderPath: String = (NSHomeDirectory() as NSString).appendingPathComponent("Documents/Earshot Notes")
    var alsoCreateAppleNotes: Bool = false

    // Mac microphone ("desk mode")
    var macMicEnabled: Bool = false

    // Privacy & integrations
    /// Replace emails, phone numbers, card/account numbers and street-address-like strings
    /// with placeholders before transcript text is sent to a cloud model.
    var redactBeforeCloud: Bool = true
    /// Serve the read-only personal-memory MCP endpoint (POST /mcp) for agents such as Claude.
    var mcpEnabled: Bool = false

    var remoteWatchSettings: RemoteWatchSettings {
        RemoteWatchSettings(segmentSeconds: segmentSeconds, silenceThresholdDB: silenceThresholdDB,
                            skipSilentSegments: skipSilentSegments, lowBatteryStopLevel: lowBatteryStopLevel)
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    var effectiveMacName: String {
        if let name = macDisplayName.nilIfEmpty { return name }
        let host = ProcessInfo.processInfo.hostName
        return host.hasSuffix(".local") ? String(host.dropLast(6)) : host
    }

    /// Tolerant decoding so adding new settings never wipes existing ones.
    init() {}

    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func v<T: Decodable>(_ key: CodingKeys, _ current: T) -> T {
            let decoded: T? = (try? c.decodeIfPresent(T.self, forKey: key)) ?? nil
            return decoded ?? current
        }
        userName = v(.userName, userName)
        aboutMe = v(.aboutMe, aboutMe)
        lifeGoals = v(.lifeGoals, lifeGoals)
        llmBackend = v(.llmBackend, llmBackend)
        claudeModel = v(.claudeModel, claudeModel)
        claudeBackgroundModel = v(.claudeBackgroundModel, claudeBackgroundModel)
        backgroundEffort = v(.backgroundEffort, backgroundEffort)
        agentEffort = v(.agentEffort, agentEffort)
        transcriptionEngine = v(.transcriptionEngine, transcriptionEngine)
        localeIdentifier = v(.localeIdentifier, localeIdentifier)
        whisperBaseURL = v(.whisperBaseURL, whisperBaseURL)
        whisperModel = v(.whisperModel, whisperModel)
        serverPort = v(.serverPort, serverPort)
        macDisplayName = v(.macDisplayName, macDisplayName)
        segmentSeconds = v(.segmentSeconds, segmentSeconds)
        silenceThresholdDB = v(.silenceThresholdDB, silenceThresholdDB)
        skipSilentSegments = v(.skipSilentSegments, skipSilentSegments)
        lowBatteryStopLevel = v(.lowBatteryStopLevel, lowBatteryStopLevel)
        keepAudioDays = v(.keepAudioDays, keepAudioDays)
        analysisIntervalMinutes = v(.analysisIntervalMinutes, analysisIntervalMinutes)
        analysisMinWords = v(.analysisMinWords, analysisMinWords)
        questionsEnabled = v(.questionsEnabled, questionsEnabled)
        maxQuestionsPerDay = v(.maxQuestionsPerDay, maxQuestionsPerDay)
        minMinutesBetweenQuestions = v(.minMinutesBetweenQuestions, minMinutesBetweenQuestions)
        quietHoursStart = v(.quietHoursStart, quietHoursStart)
        quietHoursEnd = v(.quietHoursEnd, quietHoursEnd)
        avoidQuestionsDuringConversation = v(.avoidQuestionsDuringConversation, avoidQuestionsDuringConversation)
        avoidQuestionsDuringMeetings = v(.avoidQuestionsDuringMeetings, avoidQuestionsDuringMeetings)
        dailyDigestHour = v(.dailyDigestHour, dailyDigestHour)
        weeklyReviewWeekday = v(.weeklyReviewWeekday, weeklyReviewWeekday)
        autoApproveLowRisk = v(.autoApproveLowRisk, autoApproveLowRisk)
        autoApproveMediumRisk = v(.autoApproveMediumRisk, autoApproveMediumRisk)
        computerUseEnabled = v(.computerUseEnabled, computerUseEnabled)
        agentMaxSteps = v(.agentMaxSteps, agentMaxSteps)
        notesFolderPath = v(.notesFolderPath, notesFolderPath)
        alsoCreateAppleNotes = v(.alsoCreateAppleNotes, alsoCreateAppleNotes)
        macMicEnabled = v(.macMicEnabled, macMicEnabled)
        redactBeforeCloud = v(.redactBeforeCloud, redactBeforeCloud)
        mcpEnabled = v(.mcpEnabled, mcpEnabled)
    }

    /// True when `date` falls inside quiet hours (handles ranges crossing midnight).
    func isQuietHour(_ date: Date = Date()) -> Bool {
        let hour = Calendar.current.component(.hour, from: date)
        if quietHoursStart == quietHoursEnd { return false }
        if quietHoursStart < quietHoursEnd {
            return hour >= quietHoursStart && hour < quietHoursEnd
        }
        return hour >= quietHoursStart || hour < quietHoursEnd
    }

    /// Describes the user for AI prompts.
    var profileBlock: String {
        var lines: [String] = []
        if !userName.trimmed.isEmpty { lines.append("Name: \(userName.trimmed)") }
        if !aboutMe.trimmed.isEmpty { lines.append("About: \(aboutMe.trimmed)") }
        if !lifeGoals.trimmed.isEmpty { lines.append("Stated life goals: \(lifeGoals.trimmed)") }
        return lines.isEmpty ? "(The user has not described themselves yet.)" : lines.joined(separator: "\n")
    }
}

// MARK: - Store

/// Lock-protected copy of the settings readable from any thread.
final class SettingsSnapshot: @unchecked Sendable {
    static let shared = SettingsSnapshot()
    private let lock = NSLock()
    private var value = AppSettings()

    func get() -> AppSettings {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set(_ newValue: AppSettings) {
        lock.lock()
        value = newValue
        lock.unlock()
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private static let defaultsKey = "EarshotSettings.v1"

    /// Bind UI controls to `$store.settings.someField`. Every change is persisted.
    @Published var settings: AppSettings {
        didSet { persist() }
    }

    @Published var anthropicAPIKey: String {
        didSet { Keychain.set(anthropicAPIKey.nilIfEmpty, for: Keychain.anthropicKey) }
    }

    @Published var whisperAPIKey: String {
        didSet { Keychain.set(whisperAPIKey.nilIfEmpty, for: Keychain.whisperKey) }
    }

    private init() {
        var loaded = AppSettings()
        if let data = UserDefaults.standard.data(forKey: SettingsStore.defaultsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            loaded = decoded
        }
        settings = loaded
        anthropicAPIKey = Keychain.get(Keychain.anthropicKey)
            ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        whisperAPIKey = Keychain.get(Keychain.whisperKey) ?? ""
        SettingsSnapshot.shared.set(loaded)
    }

    private func persist() {
        SettingsSnapshot.shared.set(settings)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: SettingsStore.defaultsKey)
        }
    }

    /// Thread-safe copy of the current settings, for background services.
    nonisolated static var current: AppSettings { SettingsSnapshot.shared.get() }

    /// Thread-safe reads of secrets (the Keychain API is thread-safe).
    nonisolated static var anthropicKey: String {
        Keychain.get(Keychain.anthropicKey) ?? ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
    }

    nonisolated static var whisperKey: String {
        Keychain.get(Keychain.whisperKey) ?? ""
    }
}

// MARK: - Keychain

enum Keychain {
    static let service = "com.example.earshot.mac"
    static let anthropicKey = "anthropic-api-key"
    static let whisperKey = "whisper-api-key"

    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String?, for account: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard let value, !value.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(value.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
