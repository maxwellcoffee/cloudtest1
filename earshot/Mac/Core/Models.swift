//  Models.swift
//  Internal data model of the Mac companion. Persisted by `Database`.

import Foundation

// MARK: - Audio & transcript

enum SegmentStatus: String, Codable, CaseIterable, Sendable {
    case received       // audio stored, waiting for transcription
    case transcribing
    case transcribed
    case silent         // skipped: no speech detected
    case failed
}

struct Segment: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var device: String
    var startedAt: Date
    var duration: Double
    /// Absolute path of the stored audio file, nil once retention deleted it.
    var filePath: String?
    var status: SegmentStatus
    var avgPower: Float
    var speechRatio: Float
    var reason: String
    var error: String?
    var createdAt: Date

    var endedAt: Date { startedAt.addingTimeInterval(duration) }
}

struct Utterance: Identifiable, Hashable, Codable, Sendable {
    /// Autoincrement row id. Use 0 when inserting.
    var id: Int64
    var segmentID: String
    var startedAt: Date
    var endedAt: Date
    var text: String
    var speaker: String?
}

// MARK: - Insights extracted by the AI

enum InsightKind: String, Codable, CaseIterable, Sendable {
    case task         // something the user needs to do
    case commitment   // something the user promised someone ("I'll send it Friday")
    case event        // a meeting / appointment mentioned
    case idea
    case goal         // an aspiration ("I want to run a half marathon")
    case person       // a person worth remembering (name + context)
    case fact         // a detail worth remembering (parking spot, door code)
    case decision
    case question     // an open question the user had
    case highlight    // a notable moment
    case mood         // emotional tone observation

    var label: String {
        switch self {
        case .task: return "Task"
        case .commitment: return "Commitment"
        case .event: return "Event"
        case .idea: return "Idea"
        case .goal: return "Goal"
        case .person: return "Person"
        case .fact: return "Fact"
        case .decision: return "Decision"
        case .question: return "Question"
        case .highlight: return "Highlight"
        case .mood: return "Mood"
        }
    }

    var symbol: String {
        switch self {
        case .task: return "checkmark.circle"
        case .commitment: return "hand.raised"
        case .event: return "calendar"
        case .idea: return "lightbulb"
        case .goal: return "flag"
        case .person: return "person.crop.circle"
        case .fact: return "info.circle"
        case .decision: return "signpost.right"
        case .question: return "questionmark.circle"
        case .highlight: return "star"
        case .mood: return "face.smiling"
        }
    }
}

enum InsightStatus: String, Codable, CaseIterable, Sendable {
    case open, done, dismissed
}

struct Insight: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var kind: InsightKind
    var title: String
    var detail: String
    var dueAt: Date?
    var people: [String]
    /// Transcript time range the insight came from (for "jump to source").
    var sourceFrom: Date?
    var sourceTo: Date?
    var status: InsightStatus
    var confidence: Double
    var createdAt: Date
}

// MARK: - Prompts (questions/approvals/answers delivered to the watch)

enum PromptStatus: String, Codable, CaseIterable, Sendable {
    case queued         // candidate; the scheduler decides when (and whether) to deliver
    case pending        // released for delivery; returned by /sync
    case delivered      // the watch reported it was shown
    case awaitingVoice  // user chose "just say it"; waiting for the transcript window
    case answered
    case dismissed
    case expired
}

struct StoredPrompt: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var kind: PromptKind
    var title: String
    var body: String
    var choices: [PromptChoice]
    var allowsFreeText: Bool
    var allowsVoice: Bool
    var priority: Int
    var status: PromptStatus
    /// Why the companion is asking (shown on the Mac, used for learning).
    var rationale: String
    /// Related object: insight id, goal id, action id, approval id, request id...
    var relatedID: String?
    var answerText: String?
    var answerChoiceID: String?
    var createdAt: Date
    var releasedAt: Date?
    var deliveredAt: Date?
    var answeredAt: Date?
    var expiresAt: Date?
    /// Do not release before this time (snoozed / scheduled questions).
    var notBefore: Date?

    var wire: WirePrompt {
        WirePrompt(id: id, kind: kind, title: title, body: body, choices: choices,
                   allowsFreeText: allowsFreeText, allowsVoice: allowsVoice,
                   createdAt: createdAt, expiresAt: expiresAt, priority: priority)
    }

    static func make(kind: PromptKind, title: String, body: String, choices: [PromptChoice] = [],
                     allowsFreeText: Bool = true, allowsVoice: Bool = true, priority: Int = 3,
                     status: PromptStatus = .queued, rationale: String = "", relatedID: String? = nil,
                     expiresAt: Date? = nil, notBefore: Date? = nil) -> StoredPrompt {
        StoredPrompt(id: UUID().uuidString, kind: kind, title: title, body: body, choices: choices,
                     allowsFreeText: allowsFreeText, allowsVoice: allowsVoice, priority: priority,
                     status: status, rationale: rationale, relatedID: relatedID, answerText: nil,
                     answerChoiceID: nil, createdAt: Date(), releasedAt: status == .pending ? Date() : nil,
                     deliveredAt: nil, answeredAt: nil, expiresAt: expiresAt, notBefore: notBefore)
    }
}

// MARK: - Actions the companion can take on the Mac

enum ActionKind: String, Codable, CaseIterable, Sendable {
    case reminder
    case calendarEvent
    case note
    case emailDraft
    case openURL
    case openApp
    case shortcut
    case appleScript
    case agentTask      // free-form task handed to the computer agent

    var label: String {
        switch self {
        case .reminder: return "Reminder"
        case .calendarEvent: return "Calendar event"
        case .note: return "Note"
        case .emailDraft: return "Email draft"
        case .openURL: return "Open link"
        case .openApp: return "Open app"
        case .shortcut: return "Run Shortcut"
        case .appleScript: return "AppleScript"
        case .agentTask: return "Agent task"
        }
    }

    var symbol: String {
        switch self {
        case .reminder: return "checklist"
        case .calendarEvent: return "calendar.badge.plus"
        case .note: return "note.text"
        case .emailDraft: return "envelope"
        case .openURL: return "link"
        case .openApp: return "app.badge"
        case .shortcut: return "square.stack.3d.up"
        case .appleScript: return "terminal"
        case .agentTask: return "sparkles"
        }
    }

    var risk: RiskLevel {
        switch self {
        case .note: return .low
        case .reminder, .calendarEvent, .emailDraft, .openURL, .openApp: return .medium
        case .shortcut, .appleScript, .agentTask: return .high
        }
    }
}

enum RiskLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case low, medium, high
    private var rank: Int {
        switch self {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }
    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool { lhs.rank < rhs.rank }
}

/// Flat payload: only the fields relevant to the action kind are set.
/// Dates are ISO-8601 strings exactly as produced by the model ("2026-11-14T15:00:00-08:00"
/// or "2026-11-14"); parse with `DateParsing.parse`.
struct ActionPayload: Hashable, Codable, Sendable {
    var notes: String?
    var dueISO: String?
    var startISO: String?
    var endISO: String?
    var location: String?
    var url: String?
    var appName: String?
    var recipient: String?
    var subject: String?
    var body: String?
    var shortcutName: String?
    var input: String?
    var script: String?
    var task: String?

    init(notes: String? = nil, dueISO: String? = nil, startISO: String? = nil, endISO: String? = nil,
         location: String? = nil, url: String? = nil, appName: String? = nil, recipient: String? = nil,
         subject: String? = nil, body: String? = nil, shortcutName: String? = nil, input: String? = nil,
         script: String? = nil, task: String? = nil) {
        self.notes = notes
        self.dueISO = dueISO
        self.startISO = startISO
        self.endISO = endISO
        self.location = location
        self.url = url
        self.appName = appName
        self.recipient = recipient
        self.subject = subject
        self.body = body
        self.shortcutName = shortcutName
        self.input = input
        self.script = script
        self.task = task
    }
}

enum ActionStatus: String, Codable, CaseIterable, Sendable {
    case proposed   // suggested by the AI, waiting for the user
    case approved   // approved, queued to run
    case running
    case done
    case failed
    case rejected
}

struct ProposedAction: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var kind: ActionKind
    var title: String
    var rationale: String
    var payload: ActionPayload
    var status: ActionStatus
    var result: String?
    var sourceInsightID: String?
    var createdAt: Date
    var executedAt: Date?

    static func make(kind: ActionKind, title: String, rationale: String, payload: ActionPayload,
                     sourceInsightID: String? = nil) -> ProposedAction {
        ProposedAction(id: UUID().uuidString, kind: kind, title: title, rationale: rationale, payload: payload,
                       status: .proposed, result: nil, sourceInsightID: sourceInsightID,
                       createdAt: Date(), executedAt: nil)
    }
}

struct ActionResult: Hashable, Codable, Sendable {
    var success: Bool
    var message: String
}

// MARK: - Goals & progress

enum GoalStatus: String, Codable, CaseIterable, Sendable {
    case active, paused, done
}

struct GoalNote: Hashable, Codable, Sendable {
    var date: Date
    var text: String
}

struct Goal: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var title: String
    var why: String
    var status: GoalStatus
    var createdAt: Date
    var lastCheckIn: Date?
    var notes: [GoalNote]

    static func make(title: String, why: String = "") -> Goal {
        Goal(id: UUID().uuidString, title: title, why: why, status: .active, createdAt: Date(),
             lastCheckIn: nil, notes: [])
    }
}

// MARK: - Digests

struct Digest: Identifiable, Hashable, Codable, Sendable {
    /// Day key "yyyy-MM-dd" (local time), or "week-yyyy-MM-dd" for weekly reviews.
    var day: String
    var markdown: String
    var createdAt: Date
    var id: String { day }
}

// MARK: - Devices & bookmarks

struct PairedDevice: Identifiable, Hashable, Codable, Sendable {
    var token: String
    var name: String
    var kind: String
    var pairedAt: Date
    var lastSeen: Date?
    var lastStatus: WatchStatusReport?
    var id: String { token }
}

struct StoredBookmark: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var kind: BookmarkKind
    var at: Date
    var note: String?
    var device: String
}

// MARK: - Memory chat

enum ChatRole: String, Codable, Sendable {
    case user, assistant
}

struct Citation: Hashable, Codable, Sendable {
    var utteranceID: Int64
    var at: Date
    var quote: String
}

struct ChatMessage: Identifiable, Hashable, Codable, Sendable {
    var id: String
    var role: ChatRole
    var text: String
    var citations: [Citation]
    var createdAt: Date

    static func make(role: ChatRole, text: String, citations: [Citation] = []) -> ChatMessage {
        ChatMessage(id: UUID().uuidString, role: role, text: text, citations: citations, createdAt: Date())
    }
}

// MARK: - Computer agent

enum AgentOrigin: String, Codable, Sendable {
    case mac, watch, action
}

enum AgentStepKind: String, Codable, Sendable {
    case note        // model text between tool calls
    case toolCall
    case toolResult
    case screenshot
    case approval
    case error
    case final
}

struct AgentStep: Identifiable, Hashable, Sendable {
    var id: String
    var kind: AgentStepKind
    var title: String
    var detail: String
    /// PNG data for screenshot steps (downscaled).
    var imagePNG: Data?
    var at: Date

    static func make(_ kind: AgentStepKind, _ title: String, _ detail: String = "", image: Data? = nil) -> AgentStep {
        AgentStep(id: UUID().uuidString, kind: kind, title: title, detail: detail, imagePNG: image, at: Date())
    }
}

enum AgentRunStatus: String, Codable, Sendable {
    case running, done, failed, cancelled
}

struct AgentRun: Identifiable, Hashable, Sendable {
    var id: String
    var task: String
    var origin: AgentOrigin
    var steps: [AgentStep]
    var status: AgentRunStatus
    var finalText: String
    var startedAt: Date
    var endedAt: Date?
}

// MARK: - Approvals

struct ApprovalRequest: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var detail: String
    var risk: RiskLevel
    var createdAt: Date
    /// Prompt id if the approval was also sent to the watch.
    var promptID: String?
}
