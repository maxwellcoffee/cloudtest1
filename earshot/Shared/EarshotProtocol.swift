//  EarshotProtocol.swift
//  Shared between the watchOS app and the macOS companion.
//
//  The watch talks to the Mac over plain HTTP/1.1 on the local network (or any
//  base URL the user configures, e.g. a tunnel). Every request except /hello and
//  /pair carries "Authorization: Bearer <token>" obtained by pairing with the
//  6-digit code shown on the Mac.
//
//  Dates on the wire are encoded as seconds since 1970 (Double).

import Foundation

public enum EarshotAPI {
    public static let defaultPort: UInt16 = 8737
    public static let protocolVersion = 1
    public static let bonjourType = "_earshot._tcp"

    public enum Path {
        /// GET  -> ServerHello (no auth required)
        public static let hello = "/api/v1/hello"
        /// POST PairRequest -> PairResponse (no auth required)
        public static let pair = "/api/v1/pair"
        /// POST raw audio body (audio/mp4, AAC .m4a) + SegmentMeta headers -> SegmentAck
        public static let segments = "/api/v1/segments"
        /// POST WatchStatusReport -> SyncResponse
        public static let sync = "/api/v1/sync"
        /// POST PromptAnswer -> OKResponse
        public static let answers = "/api/v1/answers"
        /// POST WatchRequest -> WatchRequestAck
        public static let requests = "/api/v1/requests"
        /// POST Bookmark -> OKResponse
        public static let bookmarks = "/api/v1/bookmarks"
    }

    public enum Header {
        public static let authorization = "Authorization"
        public static let segmentID = "X-Earshot-Segment-Id"
        public static let device = "X-Earshot-Device"
        public static let startedAt = "X-Earshot-Started-At"      // seconds since 1970
        public static let duration = "X-Earshot-Duration"         // seconds
        public static let avgPower = "X-Earshot-Avg-Power"        // dBFS, -160...0
        public static let peakPower = "X-Earshot-Peak-Power"      // dBFS, -160...0
        public static let speechRatio = "X-Earshot-Speech-Ratio"  // 0...1
        public static let reason = "X-Earshot-Reason"             // SegmentReason raw value
    }

    public static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }

    public static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }
}

// MARK: - Pairing

public struct ServerHello: Codable, Hashable {
    public var macName: String
    public var protocolVersion: Int
    public var serverTime: Date
    public init(macName: String, protocolVersion: Int, serverTime: Date) {
        self.macName = macName
        self.protocolVersion = protocolVersion
        self.serverTime = serverTime
    }
}

public struct PairRequest: Codable, Hashable {
    public var code: String
    public var deviceName: String
    public var deviceKind: String   // "watch", "mac-mic", "import"
    public init(code: String, deviceName: String, deviceKind: String) {
        self.code = code
        self.deviceName = deviceName
        self.deviceKind = deviceKind
    }
}

public struct PairResponse: Codable, Hashable {
    public var token: String
    public var macName: String
    public var protocolVersion: Int
    public init(token: String, macName: String, protocolVersion: Int) {
        self.token = token
        self.macName = macName
        self.protocolVersion = protocolVersion
    }
}

public struct OKResponse: Codable, Hashable {
    public var ok: Bool
    public var message: String?
    public init(ok: Bool = true, message: String? = nil) {
        self.ok = ok
        self.message = message
    }
}

public struct APIErrorBody: Codable, Hashable {
    public var error: String
    public init(error: String) { self.error = error }
}

// MARK: - Audio segments

/// Why a segment ended. Lets the Mac prioritise (e.g. a voice answer window).
public enum SegmentReason: String, Codable, Hashable, CaseIterable {
    case rotation       // regular fixed-length rotation
    case stopped        // user stopped recording
    case paused         // privacy pause began
    case voiceAnswer    // closed early so a spoken answer reaches the Mac quickly
    case interruption   // audio session interruption (call, Siri)
    case lowBattery
}

/// Metadata for one recorded chunk of audio. Sent as HTTP headers alongside the
/// raw .m4a body so the body can be streamed straight from disk.
public struct SegmentMeta: Codable, Hashable, Identifiable {
    public var id: String
    public var device: String
    public var startedAt: Date
    public var duration: Double
    public var avgPower: Float
    public var peakPower: Float
    public var speechRatio: Float
    public var reason: SegmentReason

    public init(id: String, device: String, startedAt: Date, duration: Double,
                avgPower: Float, peakPower: Float, speechRatio: Float, reason: SegmentReason) {
        self.id = id
        self.device = device
        self.startedAt = startedAt
        self.duration = duration
        self.avgPower = avgPower
        self.peakPower = peakPower
        self.speechRatio = speechRatio
        self.reason = reason
    }

    /// Header dictionary for URLRequest.
    public func headerFields() -> [String: String] {
        [
            EarshotAPI.Header.segmentID: id,
            EarshotAPI.Header.device: device,
            EarshotAPI.Header.startedAt: String(startedAt.timeIntervalSince1970),
            EarshotAPI.Header.duration: String(duration),
            EarshotAPI.Header.avgPower: String(avgPower),
            EarshotAPI.Header.peakPower: String(peakPower),
            EarshotAPI.Header.speechRatio: String(speechRatio),
            EarshotAPI.Header.reason: reason.rawValue,
        ]
    }

    /// Parses headers. Keys are matched case-insensitively.
    public init?(headers: [String: String]) {
        var lower: [String: String] = [:]
        for (k, v) in headers { lower[k.lowercased()] = v }
        func value(_ key: String) -> String? { lower[key.lowercased()] }
        guard let id = value(EarshotAPI.Header.segmentID), !id.isEmpty,
              let startedRaw = value(EarshotAPI.Header.startedAt),
              let started = Double(startedRaw) else { return nil }
        self.id = id
        self.device = value(EarshotAPI.Header.device) ?? "watch"
        self.startedAt = Date(timeIntervalSince1970: started)
        self.duration = Double(value(EarshotAPI.Header.duration) ?? "") ?? 0
        self.avgPower = Float(value(EarshotAPI.Header.avgPower) ?? "") ?? -160
        self.peakPower = Float(value(EarshotAPI.Header.peakPower) ?? "") ?? -160
        self.speechRatio = Float(value(EarshotAPI.Header.speechRatio) ?? "") ?? 1
        self.reason = SegmentReason(rawValue: value(EarshotAPI.Header.reason) ?? "") ?? .rotation
    }
}

public struct SegmentAck: Codable, Hashable {
    public var id: String
    public var accepted: Bool
    public var message: String?
    public init(id: String, accepted: Bool, message: String? = nil) {
        self.id = id
        self.accepted = accepted
        self.message = message
    }
}

// MARK: - Sync (watch -> Mac status, Mac -> watch prompts)

public struct WatchStatusReport: Codable, Hashable {
    public var deviceName: String
    public var isRecording: Bool
    public var pausedUntil: Date?
    public var batteryLevel: Float          // 0...1, -1 if unknown
    public var queuedSegments: Int
    public var queuedBytes: Int64
    public var lastSegmentAt: Date?
    public var recordedSecondsToday: Double
    public var appVersion: String
    /// Prompts the watch has shown to the user (so the Mac marks them delivered).
    public var deliveredPromptIDs: [String]

    public init(deviceName: String, isRecording: Bool, pausedUntil: Date?, batteryLevel: Float,
                queuedSegments: Int, queuedBytes: Int64, lastSegmentAt: Date?,
                recordedSecondsToday: Double, appVersion: String, deliveredPromptIDs: [String]) {
        self.deviceName = deviceName
        self.isRecording = isRecording
        self.pausedUntil = pausedUntil
        self.batteryLevel = batteryLevel
        self.queuedSegments = queuedSegments
        self.queuedBytes = queuedBytes
        self.lastSegmentAt = lastSegmentAt
        self.recordedSecondsToday = recordedSecondsToday
        self.appVersion = appVersion
        self.deliveredPromptIDs = deliveredPromptIDs
    }
}

public enum PromptKind: String, Codable, Hashable, CaseIterable {
    case question   // the companion asks something it thinks you want to do
    case approval   // approve/deny an action on the Mac
    case answer     // reply to an Ask / Do request from the wrist
    case nudge      // gentle reminder about a commitment or goal
    case digest     // daily/weekly summary ready
    case info       // anything else
}

public struct PromptChoice: Codable, Hashable, Identifiable {
    public var id: String
    public var title: String
    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// A prompt the Mac wants shown on the wrist.
public struct WirePrompt: Codable, Hashable, Identifiable {
    public var id: String
    public var kind: PromptKind
    public var title: String
    public var body: String
    public var choices: [PromptChoice]
    public var allowsFreeText: Bool
    /// The user can answer by simply speaking; the always-on recorder captures it.
    public var allowsVoice: Bool
    public var createdAt: Date
    public var expiresAt: Date?
    /// 1 (low) ... 5 (urgent). Controls haptic strength on the watch.
    public var priority: Int

    public init(id: String, kind: PromptKind, title: String, body: String, choices: [PromptChoice],
                allowsFreeText: Bool, allowsVoice: Bool, createdAt: Date, expiresAt: Date?, priority: Int) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.choices = choices
        self.allowsFreeText = allowsFreeText
        self.allowsVoice = allowsVoice
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.priority = priority
    }
}

public struct TodaySnapshot: Codable, Hashable {
    public var headline: String
    public var wordsToday: Int
    public var minutesRecorded: Double
    public var openTasks: Int
    public var highlights: [String]
    public var nextUp: String?
    public init(headline: String, wordsToday: Int, minutesRecorded: Double, openTasks: Int,
                highlights: [String], nextUp: String?) {
        self.headline = headline
        self.wordsToday = wordsToday
        self.minutesRecorded = minutesRecorded
        self.openTasks = openTasks
        self.highlights = highlights
        self.nextUp = nextUp
    }
    public static let empty = TodaySnapshot(headline: "", wordsToday: 0, minutesRecorded: 0,
                                            openTasks: 0, highlights: [], nextUp: nil)
}

/// Recording preferences the Mac pushes to the watch (the Mac is the single
/// place the user edits them).
public struct RemoteWatchSettings: Codable, Hashable {
    public var segmentSeconds: Int
    public var silenceThresholdDB: Float
    public var skipSilentSegments: Bool
    public var lowBatteryStopLevel: Float
    public init(segmentSeconds: Int, silenceThresholdDB: Float, skipSilentSegments: Bool, lowBatteryStopLevel: Float) {
        self.segmentSeconds = segmentSeconds
        self.silenceThresholdDB = silenceThresholdDB
        self.skipSilentSegments = skipSilentSegments
        self.lowBatteryStopLevel = lowBatteryStopLevel
    }
    public static let standard = RemoteWatchSettings(segmentSeconds: 120, silenceThresholdDB: -45,
                                                     skipSilentSegments: true, lowBatteryStopLevel: 0.10)
}

public struct SyncResponse: Codable, Hashable {
    public var serverTime: Date
    public var macName: String
    public var prompts: [WirePrompt]
    public var today: TodaySnapshot
    public var settings: RemoteWatchSettings
    public init(serverTime: Date, macName: String, prompts: [WirePrompt], today: TodaySnapshot, settings: RemoteWatchSettings) {
        self.serverTime = serverTime
        self.macName = macName
        self.prompts = prompts
        self.today = today
        self.settings = settings
    }
}

// MARK: - Answers & requests from the wrist

public enum AnswerMode: String, Codable, Hashable {
    case choice        // tapped one of `choices`
    case text          // dictated / scribbled text
    case voiceWindow   // "just say it": the Mac reads the transcript after answeredAt
    case dismissed     // "not now"
    case snoozed       // ask again later
}

public struct PromptAnswer: Codable, Hashable {
    public var promptID: String
    public var mode: AnswerMode
    public var choiceID: String?
    public var text: String?
    public var answeredAt: Date
    /// For .voiceWindow: how many seconds after answeredAt the spoken answer lasts.
    public var voiceWindowSeconds: Double?
    public init(promptID: String, mode: AnswerMode, choiceID: String? = nil, text: String? = nil,
                answeredAt: Date = Date(), voiceWindowSeconds: Double? = nil) {
        self.promptID = promptID
        self.mode = mode
        self.choiceID = choiceID
        self.text = text
        self.answeredAt = answeredAt
        self.voiceWindowSeconds = voiceWindowSeconds
    }
}

public enum WatchRequestKind: String, Codable, Hashable, CaseIterable {
    case ask       // "What did Sam say about the deadline?" -> answered from memory
    case command   // "Draft an email to Sam with today's decisions" -> Mac agent
    case note      // "Remember: parking spot 4C" -> saved as an insight
}

public struct WatchRequest: Codable, Hashable, Identifiable {
    public var id: String
    public var kind: WatchRequestKind
    public var text: String
    public var createdAt: Date
    public init(id: String = UUID().uuidString, kind: WatchRequestKind, text: String, createdAt: Date = Date()) {
        self.id = id
        self.kind = kind
        self.text = text
        self.createdAt = createdAt
    }
}

public struct WatchRequestAck: Codable, Hashable {
    public var id: String
    public var accepted: Bool
    public var message: String
    public init(id: String, accepted: Bool, message: String) {
        self.id = id
        self.accepted = accepted
        self.message = message
    }
}

public enum BookmarkKind: String, Codable, Hashable {
    case bookmark          // "remember this moment"
    case privacyPauseStart // user paused recording
    case privacyPauseEnd
}

public struct Bookmark: Codable, Hashable, Identifiable {
    public var id: String
    public var kind: BookmarkKind
    public var at: Date
    public var note: String?
    public init(id: String = UUID().uuidString, kind: BookmarkKind, at: Date = Date(), note: String? = nil) {
        self.id = id
        self.kind = kind
        self.at = at
        self.note = note
    }
}
