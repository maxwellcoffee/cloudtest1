# Earshot — module contracts

This file is the single source of truth for every cross-file API in the
project. Each module owner implements **exactly** these signatures (names,
argument labels, types, `async`/`throws`, isolation). Anything not listed here
must be `private` or `fileprivate` (helper types, extensions, functions) so two
modules can never collide on a name.

## Global rules

* Toolchain: Xcode 26+, **Swift 5 language mode** (`SWIFT_VERSION = 5.0`),
  macOS deployment target **14.0**, watchOS deployment target **10.0**.
  No third-party packages. System libraries only (SQLite3 is in the SDK).
* APIs newer than the deployment target must be wrapped in
  `if #available(macOS 26.0, *)` / `@available(...)`. Code that imports
  `FoundationModels` must be inside `#if canImport(FoundationModels)`.
* Already written (do **not** redefine or edit, just use):
  * `Shared/EarshotProtocol.swift` – wire protocol (both targets)
  * `Mac/Core/Models.swift` – Mac data model
  * `Mac/Core/Settings.swift` – `AppSettings`, `SettingsStore`, `SettingsSnapshot`, `Keychain`, enums `TranscriptionEngine`, `LLMBackend`
  * `Mac/Support/JSONValue.swift` – `JSONValue`, `Schema`
  * `Mac/Support/Support.swift` – `Log`, `DataScope`, `EarshotEvents`, `DateParsing`, `Date.dayKey/startOfDay/endOfDay/timeText/shortText/relativeText`, `String.trimmed/clipped(_:)/nilIfEmpty`, `AppPaths`
  * `Mac/AI/ClaudeClient.swift` – `ClaudeClient`, `ClaudeResponse`, `ClaudeToolUse`, `ClaudeError`
* Background code reads settings with `SettingsStore.current` (thread-safe value
  copy) and secrets with `SettingsStore.anthropicKey` / `SettingsStore.whisperKey`.
  Only UI code touches `SettingsStore.shared` (it is `@MainActor`).
* After writing to the database, post `EarshotEvents.post(.<scope>)` so the UI refreshes.
* Service classes are `final class X: @unchecked Sendable` guarding mutable
  state with an `NSLock`; they are **not** actors (so synchronous methods are
  called without `await`). Only the types explicitly marked `@MainActor` below are
  main-actor isolated.
* `Database` methods never throw; failures are logged with `Log.error` and reads
  return empty results.
* Claude models: default `claude-opus-5-5` (configurable in Settings). Use
  `ClaudeClient` for every API call. Never send `temperature`/`top_p`/`top_k`,
  `budget_tokens`, assistant prefill, or forced `tool_choice` (`any`/`tool`).
* To check an Apple API, run
  `python3 -I /tmp/claude-0/-home-user-cloudtest1/d99f2d93-75c1-597f-b5bc-c32eafe6c8b8/scratchpad/tools/appledoc.py <doc path>`
  e.g. `avfaudio/avaudiorecorder` (set `APPLEDOC_FLAGS=--topics` to list members).
  It prints declarations and platform availability from developer.apple.com.

---

## Module: infra (Mac storage, server, ingest, transcription, Mac mic)

### `Mac/Storage/Database.swift`

```swift
final class Database: @unchecked Sendable {
    init(url: URL) throws          // opens/creates SQLite (WAL), runs migrations
    // Segments
    func upsertSegment(_ s: Segment)
    func segment(id: String) -> Segment?
    func segments(from: Date, to: Date) -> [Segment]                    // startedAt asc
    func segments(statuses: [SegmentStatus], limit: Int) -> [Segment]   // oldest first
    func segmentsWithAudio(olderThan: Date) -> [Segment]
    func recordedSeconds(from: Date, to: Date) -> Double
    // Utterances (full-text indexed with FTS5; falls back to LIKE if FTS5 unavailable)
    @discardableResult func insertUtterances(_ items: [Utterance]) -> [Utterance]  // returns rows with ids
    func utterances(from: Date, to: Date, limit: Int) -> [Utterance]    // startedAt asc
    func utterances(afterID: Int64, limit: Int) -> [Utterance]          // id asc
    func utterances(segmentID: String) -> [Utterance]
    func latestUtteranceID() -> Int64                                   // 0 if none
    func searchUtterances(_ query: String, limit: Int) -> [Utterance]   // best match first
    func wordCount(from: Date, to: Date) -> Int
    func deleteUtterances(from: Date, to: Date)                         // "forget this"
    // Insights
    func upsertInsight(_ i: Insight)
    func insight(id: String) -> Insight?
    func insights(statuses: [InsightStatus]?, kinds: [InsightKind]?, since: Date?, limit: Int) -> [Insight]  // newest first; nil = no filter
    // Prompts
    func upsertPrompt(_ p: StoredPrompt)
    func prompt(id: String) -> StoredPrompt?
    func prompts(statuses: [PromptStatus], limit: Int) -> [StoredPrompt]   // newest first
    func prompts(since: Date, limit: Int) -> [StoredPrompt]                 // createdAt >= since, newest first
    func countPromptsReleased(kinds: [PromptKind], since: Date) -> Int      // releasedAt >= since
    func lastPromptRelease(kinds: [PromptKind]) -> Date?
    // Actions
    func upsertAction(_ a: ProposedAction)
    func action(id: String) -> ProposedAction?
    func actions(statuses: [ActionStatus]?, limit: Int) -> [ProposedAction]  // newest first
    // Goals
    func upsertGoal(_ g: Goal)
    func goal(id: String) -> Goal?
    func goals(statuses: [GoalStatus]?) -> [Goal]                       // newest first
    func deleteGoal(id: String)
    // Digests
    func upsertDigest(_ d: Digest)
    func digest(day: String) -> Digest?
    func digests(limit: Int) -> [Digest]                                // newest first
    // Devices
    func upsertDevice(_ d: PairedDevice)
    func device(token: String) -> PairedDevice?
    func devices() -> [PairedDevice]
    func deleteDevice(token: String)
    // Bookmarks
    func insertBookmark(_ b: StoredBookmark)
    func bookmarks(from: Date, to: Date) -> [StoredBookmark]
    // Chat
    func insertChatMessage(_ m: ChatMessage)
    func chatMessages(limit: Int) -> [ChatMessage]                      // the last `limit`, oldest first
    func clearChat()
    // Key-value store for cursors and small state
    func kvGet(_ key: String) -> String?
    func kvSet(_ key: String, _ value: String?)                         // nil deletes
    func wipeAll()                                                      // delete every row (Settings → Erase all data)
}
```
Store arrays/structs (choices, people, notes, payload, lastStatus, citations)
as JSON text columns. Dates as REAL (seconds since 1970).

### `Mac/Server/HTTPServer.swift`

```swift
struct HTTPRequest: Sendable {
    var method: String                 // "GET", "POST"
    var path: String                   // without query, e.g. "/api/v1/sync"
    var query: [String: String]
    var headers: [String: String]      // keys lowercased
    var body: Data
    func header(_ name: String) -> String?   // case-insensitive
}

struct HTTPResponse: Sendable {
    var status: Int
    var headers: [String: String]
    var body: Data
    static func json<T: Encodable>(_ value: T, status: Int = 200) -> HTTPResponse   // EarshotAPI.makeEncoder()
    static func error(_ status: Int, _ message: String) -> HTTPResponse            // APIErrorBody JSON
    static func text(_ text: String, status: Int = 200) -> HTTPResponse
}

/// Pure parser (unit-tested). Returns nil until the full head + Content-Length body is present.
enum HTTPParser {
    static func parse(_ buffer: Data) -> (request: HTTPRequest, consumed: Int)?
    static func serialize(_ response: HTTPResponse) -> Data
    static let maxBodyBytes: Int   // 64 MB; larger requests get 413
}

final class HTTPServer: @unchecked Sendable {
    init(port: UInt16, handler: @escaping @Sendable (HTTPRequest) async -> HTTPResponse)
    func start() throws          // NWListener on TCP port, Bonjour service EarshotAPI.bonjourType
    func stop()
    var isRunning: Bool { get }
    var port: UInt16 { get }
    var lastError: String? { get }
    var onStateChange: (@Sendable (_ running: Bool, _ error: String?) -> Void)?
}
```

### `Mac/Server/Pairing.swift`

```swift
final class PairingManager: @unchecked Sendable {
    init(db: Database)
    var code: String { get }              // current 6-digit code
    var codeExpiresAt: Date { get }       // rotates every 10 minutes
    func regenerateCode()
    func pair(_ request: PairRequest) -> PairedDevice?        // constant-time code check; new random token; posts .devices
    func authenticate(authorizationHeader: String?) -> PairedDevice?   // "Bearer <token>"
    func unpair(token: String)
}
```

### `Mac/Server/APIRouter.swift`

```swift
@MainActor
protocol WatchBridge: AnyObject {
    func watchDidAnswer(_ answer: PromptAnswer, device: PairedDevice) async
    func watchDidRequest(_ request: WatchRequest, device: PairedDevice) async -> WatchRequestAck
    func watchDidBookmark(_ bookmark: Bookmark, device: PairedDevice) async
    func todaySnapshot() async -> TodaySnapshot
}

final class APIRouter: @unchecked Sendable {
    init(db: Database, pairing: PairingManager, pipeline: IngestPipeline)
    weak var bridge: WatchBridge?
    func handle(_ request: HTTPRequest) async -> HTTPResponse
}
```
Routes (see `EarshotAPI.Path`): `GET hello`, `POST pair` (no auth), and with
auth: `POST segments` (meta from headers → `pipeline.ingest`), `POST sync`
(update device `lastSeen`/`lastStatus`; mark `deliveredPromptIDs` as
`.delivered` with `deliveredAt`; expire prompts past `expiresAt`; return all
prompts with status `.pending` plus `.delivered` ones from the last 6 hours
not yet answered, `TodaySnapshot` from the bridge, and
`SettingsStore.current.remoteWatchSettings`), `POST answers`, `POST requests`,
`POST bookmarks` (forwarded to the bridge). 401 for bad tokens, 404 unknown
path, 400 bad JSON.

### `Mac/Core/IngestPipeline.swift`

```swift
final class IngestPipeline: @unchecked Sendable {
    init(db: Database)
    /// Called after a segment is transcribed (any thread).
    var onTranscribed: (@Sendable (_ segment: Segment, _ utterances: [Utterance]) -> Void)?
    /// Saves audio under AppPaths.audioDirectory(for:), stores the segment (.received), schedules transcription. Idempotent per meta.id.
    func ingest(audio: Data, meta: SegmentMeta) -> SegmentAck
    /// Imports a local audio file (Mac mic, drag & drop). move=true moves instead of copying.
    func ingestFile(at url: URL, meta: SegmentMeta, move: Bool) -> SegmentAck
    func resumePending()                 // re-queue .received/.transcribing segments at launch
    @discardableResult func applyRetention() -> Int   // delete audio older than keepAudioDays
    var queueLength: Int { get }
    var statusText: String { get }       // "Idle", "Transcribing (3 queued)…"
}

/// Pure helper (unit-tested): merges recogniser pieces into sentence-like utterances.
enum UtteranceAssembler {
    static func assemble(pieces: [TranscriptPiece], segmentID: String, segmentStart: Date) -> [Utterance]
}
```
Transcription runs one segment at a time. Segments whose
`speechRatio < 0.02` (and `skipSilentSegments`) become `.silent` without
transcription. Posts `.segments`, `.utterances`.

### `Mac/Transcription/Transcribers.swift`

```swift
struct TranscriptPiece: Hashable, Sendable {
    var start: TimeInterval   // seconds from segment start
    var end: TimeInterval
    var text: String
}

protocol Transcriber: Sendable {
    var name: String { get }
    func transcribe(fileURL: URL, locale: Locale) async throws -> [TranscriptPiece]
}

enum TranscriberFactory {
    /// speechAnalyzer → SpeechAnalyzer/SpeechTranscriber on macOS 26+, else falls back to appleSpeech.
    static func make(_ settings: AppSettings) -> Transcriber
    static func requestSpeechAuthorization() async -> Bool
}
```
Implementations (file-private or internal, your choice of names prefixed
`Earshot`…): SpeechAnalyzer (macOS 26, `AssetInventory` download), SFSpeech
(on-device when `supportsOnDeviceRecognition`, `addsPunctuation`), and a
Whisper-compatible multipart client (`{whisperBaseURL}/audio/transcriptions`,
`response_format=verbose_json`, segment timestamps, key from
`SettingsStore.whisperKey`).

### `Mac/Core/MacMicRecorder.swift`

```swift
@MainActor
final class MacMicRecorder: ObservableObject {
    init(pipeline: IngestPipeline)
    @Published private(set) var isRecording: Bool
    @Published private(set) var level: Float      // dBFS of the current segment
    @Published private(set) var lastError: String?
    func start() async      // asks microphone permission, rotates AAC segments every settings.segmentSeconds
    func stop()
}
```

### `Mac/Support/NetworkInfo.swift`

```swift
enum NetworkInfo {
    static func localIPv4Addresses() -> [String]   // non-loopback, en0 first
}
```

---

## Module: ai (LLM, insights, questions, digests, memory)

### `Mac/AI/LLM.swift`

```swift
enum LLMTier: Sendable { case background, foreground }
// background → settings.claudeBackgroundModel + backgroundEffort; foreground → claudeModel + "high"

final class LLMService: @unchecked Sendable {
    static let shared: LLMService
    var isConfigured: Bool { get }          // Claude key present, or on-device model available
    var backendDescription: String { get }  // e.g. "Claude · claude-opus-5-5"
    func complete(system: String, user: String, tier: LLMTier, maxTokens: Int) async throws -> String
    func completeJSON(system: String, user: String, schema: JSONValue, tier: LLMTier, maxTokens: Int) async throws -> JSONValue
}
```
Backend `.appleOnDevice` uses Foundation Models (`#if canImport(FoundationModels)`,
macOS 26) and, for JSON, describes the schema in the instructions and parses
the first JSON object from the reply. If on-device is selected but unavailable,
fall back to Claude when a key exists.

### `Mac/AI/Prompts.swift`
Private to the ai module except:
```swift
enum PromptLibrary {
    static let companionPersona: String   // shared voice/values for every prompt
}
```

### `Mac/AI/InsightEngine.swift`

```swift
final class InsightEngine: @unchecked Sendable {
    init(db: Database, llm: LLMService)
    /// Called with newly proposed actions so the app can auto-run approved risk levels.
    var onNewActions: (@Sendable ([ProposedAction]) -> Void)?
    /// Analyses utterances since kv cursor "insights.cursor" when ≥ settings.analysisMinWords new words
    /// (or force). Writes insights, queued questions/nudges (StoredPrompt .queued), proposed actions,
    /// goal notes. Returns number of items created.
    @discardableResult func analyzeIfNeeded(force: Bool) async -> Int
    var isRunning: Bool { get }
    var lastRunAt: Date? { get }
    var lastError: String? { get }
}
```

### `Mac/AI/QuestionScheduler.swift`

```swift
/// Pure policy (unit-tested).
enum QuestionPolicy {
    static func canRelease(now: Date, settings: AppSettings, releasedToday: Int, lastRelease: Date?,
                           wordsLastFiveMinutes: Int, calendarBusy: Bool) -> (allowed: Bool, reason: String)
}

final class QuestionScheduler: @unchecked Sendable {
    init(db: Database, llm: LLMService, calendar: CalendarService)
    /// Every minute: expire stale prompts, release ≤1 queued question/nudge if QuestionPolicy allows
    /// (highest priority first, respecting notBefore).
    func tick() async
    /// Immediately make a prompt available to the watch (answers, approvals, digests bypass the budget).
    func release(_ prompt: StoredPrompt)
    /// Answer from the watch or the Mac UI. Approvals → onApprovalAnswered. Questions → stored and
    /// interpreted by the LLM (may create goals, actions, follow-up insights). voiceWindow → .awaitingVoice.
    /// snoozed → back to .queued with notBefore = now + 2h. dismissed → .dismissed.
    func handleAnswer(_ answer: PromptAnswer) async
    /// Fills .awaitingVoice answers once transcript covering the window exists (call after each transcription).
    func resolveVoiceAnswers() async
    var onApprovalAnswered: (@Sendable (_ approvalID: String, _ approved: Bool) -> Void)?
    var onNewActions: (@Sendable ([ProposedAction]) -> Void)?
    var lastDecision: String { get }   // human-readable reason of the last tick
}
```
Approval prompts use choices `PromptChoice(id: "approve", title: "Approve")`
and `PromptChoice(id: "deny", title: "Deny")`.

### `Mac/AI/DigestEngine.swift`

```swift
final class DigestEngine: @unchecked Sendable {
    init(db: Database, llm: LLMService, calendar: CalendarService)
    /// Markdown digest of `day`: summary, highlights, commitments, open loops, progress on goals,
    /// patterns, one reflection question, suggestions for tomorrow. Stores it (day key), posts .digests,
    /// and releases a .digest prompt to the watch.
    func generateDaily(for day: Date) async throws -> Digest
    /// Weekly review stored under "week-<dayKey of the end day>".
    func generateWeekly(endingOn day: Date) async throws -> Digest
    /// Runs the daily digest after settings.dailyDigestHour (once per day) and the weekly review on settings.weeklyReviewWeekday.
    func runScheduledIfNeeded() async
}
```

### `Mac/AI/MemoryChat.swift`

```swift
final class MemoryChat: @unchecked Sendable {
    init(db: Database, llm: LLMService)
    /// Answers a question from the archive (keyword + time-range retrieval, then the LLM with citations).
    /// persist=true stores both messages in chat history and posts .chat.
    func ask(_ question: String, persist: Bool) async throws -> ChatMessage
    /// Keyword search used by the agent's search_memory tool.
    func search(_ query: String, days: Int, limit: Int) -> [Utterance]
}
```

### `Mac/AI/TodayBuilder.swift`

```swift
enum TodayBuilder {
    static func snapshot(db: Database) -> TodaySnapshot   // headline from latest digest or insights; counts; ≤3 highlights; next calendar/open task
}
```

---

## Module: agent (actions on the Mac, approvals, computer use)

### `Mac/Agent/CalendarService.swift`

```swift
struct CalendarEventSummary: Hashable, Sendable {
    var title: String
    var start: Date
    var end: Date
    var location: String?
}

final class CalendarService: @unchecked Sendable {
    static let shared: CalendarService
    func requestAccess() async -> Bool                     // events + reminders (full access, macOS 14 APIs)
    var hasEventAccess: Bool { get }
    var hasReminderAccess: Bool { get }
    func isBusy(at date: Date) -> Bool                     // a non-all-day event overlaps `date`
    func upcomingEvents(hours: Double) -> [CalendarEventSummary]
    func events(on day: Date) -> [CalendarEventSummary]
    func createReminder(title: String, notes: String?, due: Date?, dateOnly: Bool) throws -> String   // returns identifier
    func createEvent(title: String, start: Date, end: Date, location: String?, notes: String?, allDay: Bool) throws -> String
}
```

### `Mac/Agent/ActionExecutor.swift`

```swift
final class ActionExecutor: @unchecked Sendable {
    init(db: Database, calendar: CalendarService)
    /// Runs the agent for .agentTask actions (set by AppModel). Returns the agent's final text.
    var agentRunner: (@Sendable (_ task: String) async -> String)?
    /// Marks running → done/failed, stores result + executedAt, posts .actions.
    func execute(_ action: ProposedAction) async -> ActionResult
    func createReminder(title: String, notes: String?, dueISO: String?) async -> ActionResult
    func createEvent(title: String, startISO: String, endISO: String?, location: String?, notes: String?) async -> ActionResult
    func createNote(title: String, body: String) async -> ActionResult        // markdown in settings.notesFolderPath (+ Apple Notes if enabled)
    func draftEmail(to: String?, subject: String, body: String) async -> ActionResult   // Mail.app visible draft, never sends
    func openURL(_ urlString: String) async -> ActionResult
    func openApp(_ name: String) async -> ActionResult
    func runShortcut(name: String, input: String?) async -> ActionResult    // /usr/bin/shortcuts run
    func listShortcuts() async -> [String]
    func runAppleScript(_ source: String) async -> ActionResult             // /usr/bin/osascript
}
```

### `Mac/Agent/ApprovalCenter.swift`

```swift
@MainActor
final class ApprovalCenter: ObservableObject {
    init(db: Database)
    @Published private(set) var pending: [ApprovalRequest]
    /// Shows the request in the Mac UI (and as a watch .approval prompt when sendToWatch).
    /// Returns true if approved; false when denied or after `timeout`.
    func requestApproval(title: String, detail: String, risk: RiskLevel, sendToWatch: Bool, timeout: TimeInterval) async -> Bool
    func resolve(id: String, approved: Bool)
    nonisolated static func isAutoApproved(_ risk: RiskLevel, settings: AppSettings) -> Bool
}
```
The watch prompt is a `StoredPrompt` (kind `.approval`, status `.pending`,
`releasedAt` = now, `relatedID` = approval id, approve/deny choices).

### `Mac/Agent/ComputerControl.swift`

```swift
struct ScreenCapture: Sendable {
    var png: Data
    var width: Int      // pixel size of the image sent to the model
    var height: Int
}

final class ComputerControl: @unchecked Sendable {
    static let shared: ComputerControl
    static var hasAccessibility: Bool { get }
    static func requestAccessibility()             // AXIsProcessTrustedWithOptions prompt
    static var hasScreenRecording: Bool { get }    // CGPreflightScreenCaptureAccess
    static func requestScreenRecording()           // CGRequestScreenCaptureAccess
    /// Main display via /usr/sbin/screencapture, downscaled to long edge ≤ 1366 px; remembers the scale.
    func screenshot() throws -> ScreenCapture
    /// Executes one computer_toolset_20260801 member (screenshot, zoom, left_click, right_click,
    /// middle_click, double_click, triple_click, left_click_drag, mouse_move, left_mouse_down,
    /// left_mouse_up, cursor_position, scroll, type, key, hold_key, wait).
    /// Coordinates are in screenshot pixel space. Returns text and/or an image for the tool_result.
    func perform(member: String, input: JSONValue) async throws -> (text: String, image: ScreenCapture?)
}
```

### `Mac/Agent/ComputerAgent.swift`

```swift
@MainActor
final class ComputerAgent: ObservableObject {
    init(db: Database, executor: ActionExecutor, approvals: ApprovalCenter, memory: MemoryChat, calendar: CalendarService)
    @Published private(set) var runs: [AgentRun]       // newest first, last 30
    @Published private(set) var current: AgentRun?
    var isRunning: Bool { get }
    /// Tool-use loop with Claude: custom tools (create_reminder, create_calendar_event, create_note,
    /// draft_email, open_url, open_app, run_shortcut, list_shortcuts, run_applescript, search_memory,
    /// get_today, list_upcoming_events) plus, when settings.computerUseEnabled, the
    /// {"type":"computer_toolset_20260801"} toolset. Medium/high-risk tools ask ApprovalCenter
    /// (sendToWatch when origin == .watch). Stops at settings.agentMaxSteps or on cancel().
    func run(task: String, origin: AgentOrigin) async -> AgentRun
    func cancel()
}
```

---

## Module: ui (Mac app entry, AppModel wiring, all Mac views)

### `Mac/EarshotMacApp.swift`
`@main struct EarshotMacApp: App` – `WindowGroup` (main window), `MenuBarExtra`
(status + quick actions), `Settings` scene.

### `Mac/Core/AppModel.swift`

```swift
@MainActor
final class AppModel: ObservableObject, WatchBridge {
    static let shared: AppModel
    let settings: SettingsStore
    let db: Database
    let pairing: PairingManager
    let pipeline: IngestPipeline
    let router: APIRouter
    let server: HTTPServer
    let llm: LLMService
    let insightEngine: InsightEngine
    let scheduler: QuestionScheduler
    let digestEngine: DigestEngine
    let memory: MemoryChat
    let calendar: CalendarService
    let executor: ActionExecutor
    let approvals: ApprovalCenter
    let agent: ComputerAgent
    let micRecorder: MacMicRecorder
    func start()   // server, resumePending, 60 s timer (scheduler.tick, insight analysis every analysisIntervalMinutes, digests, retention), permissions
}
```
Wiring: `router.bridge = self`; `pipeline.onTranscribed` → `scheduler.resolveVoiceAnswers()`
and (throttled) `insightEngine.analyzeIfNeeded(force: false)`;
`insightEngine.onNewActions` / `scheduler.onNewActions` → auto-execute when
`ApprovalCenter.isAutoApproved(kind.risk, settings:)`, otherwise leave them
`.proposed` in the Inbox (only the agent asks for approvals on the watch);
`scheduler.onApprovalAnswered` → `approvals.resolve`;
`executor.agentRunner` → `agent.run(task:origin: .action).finalText`.
`watchDidRequest`: `.ask` → `memory.ask` then release a `.answer` prompt;
`.command` → `agent.run(origin: .watch)` then release an `.answer` prompt;
`.note` → store an `Insight` (kind `.fact`, or `.idea`).

### `Mac/Views/*`
Sidebar sections: Today (live transcript timeline grouped by segment, insights
rail, bookmarks), Ask (memory chat), Inbox (questions waiting/answered,
proposed actions with Approve/Run/Dismiss, pending approvals), Goals, Digests,
Agent (task box, live steps with screenshots, cancel), Devices (pairing code,
IP addresses, port, paired watches with last status/battery/queue), Settings
(all `AppSettings` fields, API keys, permissions buttons, erase data).

---

## Module: watch (watchOS app)

Standalone watch-only app (`WKApplication`, `WKWatchOnly`), files under
`Watch/`. Uses only `Shared/EarshotProtocol.swift` from the shared code. Talks
to the Mac with `URLSession` (`http://<host>:<port>` entered in Settings, or
any https base URL). Store-and-forward: segments are queued on disk and
uploaded oldest-first whenever the Mac is reachable.

---

## Module: project
`project.yml` (XcodeGen), `Mac/Info.plist`, `Mac/Earshot.entitlements`,
`Watch/Info.plist`, `scripts/bootstrap.sh`, `MacTests/*.swift` (tests for
`JSONValue`, `Schema`, `DateParsing`, `AppSettings.isQuietHour`,
`SegmentMeta` header round-trip, `ClaudeClient.makeBody`, `HTTPParser`,
`UtteranceAssembler`, `QuestionPolicy`), `README.md`.
