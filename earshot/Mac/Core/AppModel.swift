//  AppModel.swift
//  Composition root of the Mac companion. Owns every service, wires their
//  callbacks together, implements the watch bridge used by the HTTP API, and
//  publishes main-actor state for the SwiftUI views. Published collections are
//  reloaded from the database (off the main thread, debounced) whenever a
//  service posts an `EarshotEvents` change for the matching scope.

import Foundation
import AppKit
import AVFoundation
import CoreMedia
import Combine
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject, WatchBridge {
    static let shared = AppModel()

    /// UserDefaults flag set once onboarding finished (also read with @AppStorage).
    nonisolated static let onboardingDefaultsKey = "earshot.onboardingComplete.v1"

    // MARK: - UI types

    enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
        case today, ask, inbox, goals, digests, agent, devices, settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .today: return "Today"
            case .ask: return "Ask"
            case .inbox: return "Inbox"
            case .goals: return "Goals"
            case .digests: return "Digests"
            case .agent: return "Agent"
            case .devices: return "Devices"
            case .settings: return "Settings"
            }
        }

        var symbol: String {
            switch self {
            case .today: return "sun.max"
            case .ask: return "bubble.left.and.bubble.right"
            case .inbox: return "tray"
            case .goals: return "flag"
            case .digests: return "doc.text"
            case .agent: return "sparkles"
            case .devices: return "applewatch"
            case .settings: return "gearshape"
            }
        }
    }

    /// A short message shown at the bottom of the main window.
    struct Banner: Identifiable, Equatable {
        enum Style: Equatable { case info, success, warning, error }
        let id = UUID()
        var style: Style
        var text: String
    }

    // MARK: - Services (contract)

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
    /// Personal-memory MCP endpoint (POST /mcp), served while `mcpEnabled` is on.
    let mcp: MCPHandler

    // MARK: - Navigation state

    @Published var sidebarSelection: SidebarItem? = .today {
        didSet {
            // Leaving Today ends a jump to a cited utterance, so Today follows the live transcript again.
            if sidebarSelection != .today && highlightedUtteranceID != nil {
                highlightedUtteranceID = nil
            }
        }
    }
    /// Start of the day shown in Today.
    @Published var selectedDay: Date = Date().startOfDay {
        didSet {
            if !Calendar.current.isDate(oldValue, inSameDayAs: selectedDay) {
                // A highlight belongs to the day it was shown on (`show(date:utteranceID:)` sets it after the day).
                if highlightedUtteranceID != nil { highlightedUtteranceID = nil }
                scheduleReload([.segments, .utterances], delay: 0.05)
            }
        }
    }
    /// Utterance to scroll to and highlight in Today (citations, "show source"). While set, Today
    /// does not auto-scroll to new speech; it is cleared when the day changes or Today is left.
    @Published var highlightedUtteranceID: Int64? = nil
    @Published var selectedDigestID: String? = nil
    @Published var banner: Banner? = nil

    // MARK: - Data (reloaded from the database)

    @Published private(set) var utterances: [Utterance] = []
    @Published private(set) var segments: [Segment] = []
    @Published private(set) var bookmarks: [StoredBookmark] = []
    @Published private(set) var insights: [Insight] = []
    @Published private(set) var prompts: [StoredPrompt] = []
    @Published private(set) var actions: [ProposedAction] = []
    @Published private(set) var goals: [Goal] = []
    @Published private(set) var digests: [Digest] = []
    @Published private(set) var devices: [PairedDevice] = []
    @Published private(set) var chat: [ChatMessage] = []
    @Published private(set) var dayWordCount = 0
    @Published private(set) var dayRecordedSeconds: Double = 0
    @Published private(set) var todayWordCount = 0

    // MARK: - Status

    @Published private(set) var serverRunning = false
    @Published private(set) var serverError: String? = nil
    @Published private(set) var pipelineStatus = "Idle"
    @Published private(set) var analysisStatus = "Waiting for enough new speech"
    @Published private(set) var questionStatus = ""
    @Published private(set) var lastAnalysisAt: Date? = nil
    @Published private(set) var isAnalyzing = false
    @Published private(set) var aiConfigured = false
    @Published private(set) var aiBackendDescription = ""
    @Published private(set) var databaseWarning: String? = nil
    @Published private(set) var permissionsRevision = 0

    // MARK: - Activity

    @Published private(set) var pendingQuestion: String? = nil
    @Published private(set) var askError: String? = nil
    @Published private(set) var isGeneratingDigest = false
    @Published private(set) var digestError: String? = nil
    @Published private(set) var runningActionIDs: Set<String> = []
    @Published private(set) var importsInProgress = 0
    /// Agent runs started through the app (running + waiting).
    @Published private(set) var agentQueueDepth = 0
    @Published private(set) var isExporting = false
    /// True while Settings → Erase all data is running (the wipe runs off the main thread).
    @Published private(set) var isErasing = false
    @Published private(set) var exportError: String? = nil
    @Published private(set) var lastExportURL: URL? = nil

    // MARK: - Private state

    private var started = false
    private var timer: Timer?
    private var eventObserver: NSObjectProtocol?
    private var settingsObserver: AnyCancellable?
    /// Re-publishes MacMicRecorder.isRecording changes so views that read `model.micRecorder.isRecording` refresh.
    private var micObserver: AnyCancellable?
    private var pendingScopes: Set<DataScope> = []
    private var reloadTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var deferredAnalysis: Task<Void, Never>?
    private var digestCheckTask: Task<Void, Never>?
    private var agentChain: Task<Void, Never>?
    private var lastAutoAnalysisAt: Date?
    private var lastIntervalAnalysisAt: Date = .distantPast
    private var lastRetentionAt: Date = .distantPast
    private var tickInFlight = false
    /// The calendar day the app last treated as today (see `rollOverDayIfNeeded`).
    private var lastKnownToday = Date().startOfDay
    /// Set at midnight while Today shows the day that just ended: Today moves to the new day once
    /// the user is no longer reading a cited passage of it.
    private var dayRolloverFrom: Date?
    /// Accepted watch requests by request id, loaded lazily from the key-value store (nil until then).
    private var handledWatchRequests: [String: HandledWatchRequest]?
    /// Recently forgotten time ranges, loaded lazily from the key-value store (nil until then).
    private var forgottenRanges: [ForgottenRange]?

    /// Transcription-triggered analysis runs at most this often.
    private static let autoAnalysisSpacing: TimeInterval = 180
    private static let handledWatchRequestsKey = "watch.handledRequests.v1"
    /// A watch resends a request until it sees a response; older ids are forgotten.
    private static let handledWatchRequestLifetime: TimeInterval = 7 * 86_400
    private static let handledWatchRequestLimit = 300

    /// The acknowledgement already sent for a watch request (see `watchDidRequest`).
    private struct HandledWatchRequest: Codable {
        var ack: WatchRequestAck
        var at: Date
    }
    private typealias HandledWatchRequestTable = [String: HandledWatchRequest]

    /// A time range the user asked to forget. Kept for a while so that audio which was still on the
    /// watch, in the transcription queue or in the Mac's current segment at that moment is scrubbed
    /// once it has been transcribed, stored as silent or marked failed (see `scrubIfForgotten`).
    private struct ForgottenRange: Codable {
        var from: Date
        var to: Date
        var at: Date
    }
    private static let forgottenRangesKey = "forget.ranges.v1"
    /// A watch can keep audio offline for days; older forget requests are no longer re-applied.
    private static let forgottenRangeLifetime: TimeInterval = 7 * 86_400
    private static let forgottenRangeLimit = 200
    /// Utterances are at most about 25 s long; this finds every one that starts before a range and runs into it.
    private static let forgetUtteranceLookback: TimeInterval = 900
    /// Imported recordings can be long; segments that started up to this long before a range are checked.
    private static let forgetSegmentLookback: TimeInterval = 86_400

    // MARK: - Init

    private init() {
        let settingsStore = SettingsStore.shared
        let current = settingsStore.settings
        let opened = AppModel.openDatabase()
        let database = opened.database
        let pairing = PairingManager(db: database)
        let pipeline = IngestPipeline(db: database)
        let router = APIRouter(db: database, pairing: pairing, pipeline: pipeline)
        let llm = LLMService.shared
        let calendar = CalendarService.shared
        let memory = MemoryChat(db: database, llm: llm)
        let executor = ActionExecutor(db: database, calendar: calendar)
        let approvals = ApprovalCenter(db: database)
        let mcp = MCPHandler(db: database, memory: memory)

        self.settings = settingsStore
        self.db = database
        self.pairing = pairing
        self.pipeline = pipeline
        self.router = router
        self.server = HTTPServer(port: AppModel.validPort(current.serverPort),
                                 handler: { [router] request in await router.handle(request) })
        self.llm = llm
        self.insightEngine = InsightEngine(db: database, llm: llm)
        self.scheduler = QuestionScheduler(db: database, llm: llm, calendar: calendar)
        self.digestEngine = DigestEngine(db: database, llm: llm, calendar: calendar)
        self.memory = memory
        self.calendar = calendar
        self.executor = executor
        self.approvals = approvals
        self.agent = ComputerAgent(db: database, executor: executor, approvals: approvals,
                                   memory: memory, calendar: calendar)
        self.micRecorder = MacMicRecorder(pipeline: pipeline)
        self.mcp = mcp

        databaseWarning = opened.warning
        router.mcp = mcp
        router.bridge = self
        wireCallbacks()
        observeChanges()
        refreshAIStatus()
        scheduleReload(Set(DataScope.allCases), delay: 0)
    }

    private static func openDatabase() -> (database: Database, warning: String?) {
        let primary = AppPaths.databaseURL
        do {
            let database = try Database(url: primary)
            return (database, nil)
        } catch {
            Log.error("AppModel: could not open the database at \(primary.path): \(error.localizedDescription). Falling back to a temporary database.")
        }
        let warning = "Earshot couldn't open its database in \(primary.deletingLastPathComponent().path), so this session uses a temporary one that is not kept. Check free disk space and folder permissions, then restart Earshot."
        let fallback = AppPaths.temporaryDirectory.appendingPathComponent("earshot-fallback-\(UUID().uuidString).sqlite")
        do {
            let database = try Database(url: fallback)
            return (database, warning)
        } catch {
            Log.error("AppModel: could not open the fallback database at \(fallback.path): \(error.localizedDescription).")
        }
        let lastResort = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("earshot-\(UUID().uuidString).sqlite")
        Log.error("AppModel: using last-resort database at \(lastResort.path).")
        // A database is required for the app to function at all; failing here means the
        // temporary directory itself is unusable.
        let database = try! Database(url: lastResort)
        return (database, warning)
    }

    private static func validPort(_ value: Int) -> UInt16 {
        guard value > 0, let port = UInt16(exactly: value) else {
            Log.error("AppModel: invalid server port \(value); using \(EarshotAPI.defaultPort).")
            return EarshotAPI.defaultPort
        }
        return port
    }

    // MARK: - Wiring

    private func wireCallbacks() {
        server.onStateChange = { [weak self] running, error in
            Task { @MainActor in
                self?.serverStateChanged(running: running, error: error)
            }
        }
        pipeline.onTranscribed = { [weak self] segment, utterances in
            Task { @MainActor in
                self?.handleTranscribed(segment, utterances)
            }
        }
        // Silent or failed segments keep their audio for a while; a forget request covers them too.
        pipeline.onNotTranscribed = { [weak self] segment in
            Task { @MainActor in
                self?.scrubIfForgotten(segment)
            }
        }
        let actionHandler: @Sendable ([ProposedAction]) -> Void = { [weak self] actions in
            Task { @MainActor in
                self?.handleNewActions(actions)
            }
        }
        insightEngine.onNewActions = actionHandler
        scheduler.onNewActions = actionHandler
        scheduler.onApprovalAnswered = { [weak self] approvalID, approved in
            Task { @MainActor in
                self?.approvals.resolve(id: approvalID, approved: approved)
            }
        }
        executor.agentRunner = { [weak self] task in
            guard let self else { return "Earshot is not running, so the agent task was skipped." }
            let run = await self.enqueueAgentRun(task: task, origin: .action)
            return run.finalText
        }
    }

    private func observeChanges() {
        eventObserver = NotificationCenter.default.addObserver(forName: EarshotEvents.changed, object: nil,
                                                               queue: .main) { [weak self] note in
            guard let scope = EarshotEvents.scope(of: note) else { return }
            Task { @MainActor in
                self?.scheduleReload([scope])
            }
        }
        settingsObserver = settings.objectWillChange
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAIStatus()
                }
            }
        // Only `isRecording`: the meter level changes twice a second while recording, and views that
        // need it observe the recorder themselves (MacMicCard, MenuMicButton).
        micObserver = micRecorder.$isRecording
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)   // $isRecording emits in willSet; deliver after the change
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    // MARK: - Lifecycle

    /// Starts the server, resumes pending transcription, the minute timer and desk mode.
    func start() {
        guard !started else { return }
        started = true
        Log.info("AppModel: starting (data in \(AppPaths.supportDirectory.path)).")

        do {
            try server.start()
            serverError = nil
        } catch {
            serverError = error.localizedDescription
            Log.error("AppModel: HTTP server failed to start on port \(server.port): \(error.localizedDescription)")
        }
        serverRunning = server.isRunning

        let pipeline = self.pipeline
        Task.detached(priority: .utility) {
            pipeline.resumePending()
        }

        startTimer()

        if UserDefaults.standard.bool(forKey: AppModel.onboardingDefaultsKey) {
            Task { await self.requestStartupPermissions() }
        }
        if settings.settings.macMicEnabled {
            Task { [weak self] in
                guard let self else { return }
                await self.micRecorder.start()
                self.stopMicIfDisabled()
            }
        }
        refreshStatus()

        // First housekeeping pass shortly after launch (catch up on anything recorded while closed).
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            await self?.minuteTick()
        }
    }

    /// Called when the app terminates.
    func shutdown() {
        timer?.invalidate()
        timer = nil
        if micRecorder.isRecording { micRecorder.stop() }
        server.stop()
        Log.info("AppModel: stopped.")
    }

    private func startTimer() {
        self.timer?.invalidate()
        let minuteTimer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.minuteTick()
            }
        }
        minuteTimer.tolerance = 5
        RunLoop.main.add(minuteTimer, forMode: .common)
        self.timer = minuteTimer
    }

    private func minuteTick() async {
        // Before the in-flight guard: a slow scheduler pass must not hold Today on yesterday.
        rollOverDayIfNeeded()
        // Skip housekeeping while an erase is running: it would read (and act on) the old data.
        guard !tickInFlight, !isErasing else { return }
        tickInFlight = true
        defer { tickInFlight = false }

        await scheduler.tick()

        let now = Date()
        let interval = TimeInterval(max(1, settings.settings.analysisIntervalMinutes) * 60)
        if now.timeIntervalSince(lastIntervalAnalysisAt) >= interval {
            if startAnalysis(force: false, automatic: true) {
                lastIntervalAnalysisAt = now
            }
        }

        if digestCheckTask == nil {
            let engine = digestEngine
            digestCheckTask = Task { [weak self] in
                await engine.runScheduledIfNeeded()
                self?.digestCheckTask = nil
            }
        }

        if now.timeIntervalSince(lastRetentionAt) >= 3600 {
            lastRetentionAt = now
            let pipeline = self.pipeline
            Task.detached(priority: .background) {
                let removed = pipeline.applyRetention()
                if removed > 0 {
                    Log.info("AppModel: retention removed the audio of \(removed) segment(s).")
                }
            }
        }

        refreshAIStatus()
        refreshStatus()
    }

    /// Moves Today to the new day after midnight (the app keeps running for days in the menu bar).
    /// Someone who was looking at the day that just ended follows the clock; someone looking at an
    /// older day stays there. While a cited passage of the old day is open, the move waits for it.
    private func rollOverDayIfNeeded() {
        let today = Date().startOfDay
        if today != lastKnownToday {
            if Calendar.current.isDate(selectedDay, inSameDayAs: lastKnownToday) {
                dayRolloverFrom = lastKnownToday
            }
            lastKnownToday = today
            // Recomputes `todayWordCount` for the new day (and the shown day's figures).
            scheduleReload([.utterances], delay: 0)
        }
        guard let from = dayRolloverFrom else { return }
        guard Calendar.current.isDate(selectedDay, inSameDayAs: from) else {
            // The user moved to another day (or to today) in the meantime.
            dayRolloverFrom = nil
            return
        }
        guard highlightedUtteranceID == nil else { return }
        dayRolloverFrom = nil
        selectedDay = today   // didSet reloads the segments and utterances of the new day
    }

    private func requestStartupPermissions() async {
        let calendar = self.calendar
        let calendarGranted = await calendar.requestAccess()
        if !calendarGranted {
            Log.info("AppModel: calendar/reminders access not granted; questions will not know about meetings.")
        }
        if settings.settings.transcriptionEngine != .whisperAPI {
            let speechGranted = await TranscriberFactory.requestSpeechAuthorization()
            if !speechGranted {
                Log.info("AppModel: speech recognition not authorized; on-device transcription will fail until it is granted.")
            }
        }
        permissionsRevision += 1
    }

    // MARK: - Reloading

    private struct ReloadRequest: Sendable {
        var scopes: Set<DataScope>
        var day: Date
        var now: Date
    }

    private struct ReloadResult: Sendable {
        var day: Date
        var utterances: [Utterance]?
        var segments: [Segment]?
        var bookmarks: [StoredBookmark]?
        var dayWords: Int?
        var dayRecordedSeconds: Double?
        var todayWords: Int?
        var insights: [Insight]?
        var prompts: [StoredPrompt]?
        var actions: [ProposedAction]?
        var goals: [Goal]?
        var digests: [Digest]?
        var devices: [PairedDevice]?
        var chat: [ChatMessage]?

        init(day: Date) {
            self.day = day
        }
    }

    private func scheduleReload(_ scopes: Set<DataScope>, delay: TimeInterval = 0.3) {
        pendingScopes.formUnion(scopes)
        guard reloadTask == nil else { return }
        let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
        reloadTask = Task { [weak self] in
            if nanoseconds > 0 {
                try? await Task.sleep(nanoseconds: nanoseconds)
            }
            await self?.drainReloads()
        }
    }

    /// Fetches pending scopes one batch at a time so results are applied in order.
    private func drainReloads() async {
        while !pendingScopes.isEmpty {
            let request = ReloadRequest(scopes: pendingScopes, day: selectedDay, now: Date())
            pendingScopes.removeAll()
            let db = self.db
            let result = await Task.detached(priority: .userInitiated) {
                AppModel.fetch(request, db: db)
            }.value
            apply(result)
        }
        reloadTask = nil
    }

    nonisolated private static func fetch(_ request: ReloadRequest, db: Database) -> ReloadResult {
        var result = ReloadResult(day: request.day)
        let scopes = request.scopes
        let dayStart = request.day.startOfDay
        let dayEnd = request.day.endOfDay

        if scopes.contains(.utterances) {
            result.utterances = db.utterances(from: dayStart, to: dayEnd, limit: 5000)
            let dayWords = db.wordCount(from: dayStart, to: dayEnd)
            result.dayWords = dayWords
            if Calendar.current.isDate(request.now, inSameDayAs: dayStart) {
                result.todayWords = dayWords
            } else {
                result.todayWords = db.wordCount(from: request.now.startOfDay, to: request.now.endOfDay)
            }
        }
        if scopes.contains(.segments) {
            result.segments = db.segments(from: dayStart, to: dayEnd)
            result.dayRecordedSeconds = db.recordedSeconds(from: dayStart, to: dayEnd)
        }
        if scopes.contains(.utterances) || scopes.contains(.segments) || scopes.contains(.status) {
            result.bookmarks = db.bookmarks(from: dayStart, to: dayEnd)
        }
        if scopes.contains(.insights) {
            let open = db.insights(statuses: [.open], kinds: nil, since: nil, limit: 500)
            let recent = db.insights(statuses: nil, kinds: nil, since: nil, limit: 300)
            result.insights = uniqueByID(open + recent).sorted { $0.createdAt > $1.createdAt }
        }
        if scopes.contains(.prompts) {
            let recent = db.prompts(since: request.now.addingTimeInterval(-14 * 86_400), limit: 200)
            let waiting = db.prompts(statuses: [.queued, .pending, .delivered, .awaitingVoice], limit: 200)
            result.prompts = uniqueByID(waiting + recent).sorted { $0.createdAt > $1.createdAt }
        }
        if scopes.contains(.actions) {
            let recent = db.actions(statuses: nil, limit: 200)
            let active = db.actions(statuses: [.proposed, .approved, .running], limit: 200)
            result.actions = uniqueByID(active + recent).sorted { $0.createdAt > $1.createdAt }
        }
        if scopes.contains(.goals) {
            result.goals = db.goals(statuses: nil)
        }
        if scopes.contains(.digests) {
            result.digests = db.digests(limit: 60)
        }
        if scopes.contains(.devices) {
            result.devices = db.devices()
        }
        if scopes.contains(.chat) {
            result.chat = db.chatMessages(limit: 200)
        }
        return result
    }

    private func apply(_ result: ReloadResult) {
        if Calendar.current.isDate(result.day, inSameDayAs: selectedDay) {
            if let value = result.utterances, value != utterances { utterances = value }
            if let value = result.segments, value != segments { segments = value }
            if let value = result.bookmarks, value != bookmarks { bookmarks = value }
            if let value = result.dayWords, value != dayWordCount { dayWordCount = value }
            if let value = result.dayRecordedSeconds, value != dayRecordedSeconds { dayRecordedSeconds = value }
        }
        if let value = result.todayWords, value != todayWordCount { todayWordCount = value }
        if let value = result.insights, value != insights { insights = value }
        if let value = result.prompts, value != prompts { prompts = value }
        if let value = result.actions, value != actions { actions = value }
        if let value = result.goals, value != goals { goals = value }
        if let value = result.digests, value != digests { digests = value }
        if let value = result.devices, value != devices { devices = value }
        if let value = result.chat, value != chat { chat = value }
        refreshStatus()
    }

    /// Reloads everything (e.g. after waking from sleep or erasing data).
    func reloadAll() {
        scheduleReload(Set(DataScope.allCases), delay: 0)
    }

    // MARK: - Status

    private func assign<Value: Equatable>(_ value: Value, to keyPath: ReferenceWritableKeyPath<AppModel, Value>) {
        if self[keyPath: keyPath] != value {
            self[keyPath: keyPath] = value
        }
    }

    private func serverStateChanged(running: Bool, error: String?) {
        assign(running, to: \.serverRunning)
        if running {
            assign(nil, to: \.serverError)
        } else if let error {
            assign(error, to: \.serverError)
            Log.error("AppModel: server stopped: \(error)")
        }
    }

    /// Refreshes cheap, non-database status (server, pipeline, analysis, scheduler).
    func refreshStatus() {
        let running = server.isRunning
        assign(running, to: \.serverRunning)
        if running {
            assign(nil, to: \.serverError)
        } else if let error = server.lastError {
            assign(error, to: \.serverError)
        }
        assign(pipeline.statusText, to: \.pipelineStatus)
        assign(scheduler.lastDecision, to: \.questionStatus)
        if let ranAt = insightEngine.lastRunAt {
            assign(Optional(ranAt), to: \.lastAnalysisAt)
        }
        let busy = insightEngine.isRunning || analysisTask != nil
        assign(busy, to: \.isAnalyzing)
        let status: String
        if busy {
            status = "Analyzing the transcript…"
        } else if let error = insightEngine.lastError?.nilIfEmpty {
            status = "Last analysis failed: \(error)"
        } else if lastAnalysisAt != nil {
            status = "Up to date"
        } else {
            status = "Waiting for enough new speech"
        }
        assign(status, to: \.analysisStatus)
    }

    func refreshAIStatus() {
        assign(llm.isConfigured, to: \.aiConfigured)
        assign(llm.backendDescription, to: \.aiBackendDescription)
    }

    func showBanner(_ style: Banner.Style, _ text: String) {
        let banner = Banner(style: style, text: text)
        self.banner = banner
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard let self, self.banner?.id == banner.id else { return }
            self.banner = nil
        }
    }

    // MARK: - Derived state for views

    var isViewingToday: Bool { Calendar.current.isDateInToday(selectedDay) }

    var openTaskCount: Int {
        insights.filter { $0.status == .open && ($0.kind == .task || $0.kind == .commitment) }.count
    }

    var proposedActions: [ProposedAction] {
        actions.filter { $0.status == .proposed }
    }

    var activeActions: [ProposedAction] {
        actions.filter { $0.status == .approved || $0.status == .running }
    }

    /// Questions and nudges that still wait for the user (queued, on the watch, or awaiting a spoken answer).
    var openQuestions: [StoredPrompt] {
        prompts.filter { prompt in
            (prompt.kind == .question || prompt.kind == .nudge)
                && (prompt.status == .queued || prompt.status == .pending
                    || prompt.status == .delivered || prompt.status == .awaitingVoice)
        }
    }

    /// Released questions the user has not answered yet (for badges).
    var unansweredPromptCount: Int {
        prompts.filter { prompt in
            (prompt.kind == .question || prompt.kind == .nudge)
                && (prompt.status == .pending || prompt.status == .delivered || prompt.status == .awaitingVoice)
        }.count
    }

    var lastWatchContact: Date? {
        devices.filter { $0.kind == "watch" }.compactMap { $0.lastSeen }.max()
    }

    var hasPairedWatch: Bool {
        devices.contains { $0.kind == "watch" }
    }

    // MARK: - Transcription & analysis

    private func handleTranscribed(_ segment: Segment, _ utterances: [Utterance]) {
        // Audio recorded before a "forget" but transcribed after it must not bring the speech back.
        scrubIfForgotten(segment)
        let scheduler = self.scheduler
        Task {
            await scheduler.resolveVoiceAnswers()
        }
        guard !utterances.isEmpty else { return }
        Log.debug("AppModel: \(utterances.count) utterance(s) transcribed in segment \(segment.id).")
        requestThrottledAnalysis()
    }

    /// Analysis triggered by new transcripts: at most once per `autoAnalysisSpacing`, single flight.
    private func requestThrottledAnalysis() {
        guard deferredAnalysis == nil else { return }
        let now = Date()
        if let last = lastAutoAnalysisAt, now.timeIntervalSince(last) < AppModel.autoAnalysisSpacing {
            let wait = AppModel.autoAnalysisSpacing - now.timeIntervalSince(last)
            let nanoseconds = UInt64(max(1, wait) * 1_000_000_000)
            deferredAnalysis = Task { [weak self] in
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard let self else { return }
                self.deferredAnalysis = nil
                self.startAnalysis(force: false, automatic: true)
            }
            return
        }
        startAnalysis(force: false, automatic: true)
    }

    /// Starts an analysis pass unless one is already running. Returns false when skipped.
    @discardableResult
    private func startAnalysis(force: Bool, automatic: Bool) -> Bool {
        if analysisTask != nil || insightEngine.isRunning || isErasing { return false }
        if automatic { lastAutoAnalysisAt = Date() }
        isAnalyzing = true
        analysisStatus = force ? "Analyzing your day…" : "Checking for new speech…"
        let engine = insightEngine
        analysisTask = Task { [weak self] in
            let created = await engine.analyzeIfNeeded(force: force)
            guard let self else { return }
            self.analysisTask = nil
            self.finishAnalysis(created: created, forced: force)
        }
        return true
    }

    private func finishAnalysis(created: Int, forced: Bool) {
        if let ranAt = insightEngine.lastRunAt { lastAnalysisAt = ranAt }
        refreshStatus()
        if created > 0 {
            Log.info("AppModel: analysis created \(created) item(s).")
        }
        guard forced else { return }
        if created > 0 {
            showBanner(.success, created == 1 ? "Found 1 new item." : "Found \(created) new items.")
        } else if let error = insightEngine.lastError?.nilIfEmpty {
            showBanner(.error, "Analysis failed: \(error)")
        } else {
            showBanner(.info, "Analysis finished. Nothing new to add.")
        }
    }

    /// "Analyze now" from the toolbar or menu bar.
    func analyzeNow() {
        refreshAIStatus()
        guard aiConfigured else {
            showBanner(.warning, "Add an Anthropic API key in Settings → AI (or choose the on-device model) to analyze your day.")
            return
        }
        if isErasing {
            showBanner(.info, "Earshot is erasing your data. Try again when it has finished.")
        } else if !startAnalysis(force: true, automatic: false) {
            showBanner(.info, "An analysis is already running.")
        }
    }

    // MARK: - Actions

    private func handleNewActions(_ newActions: [ProposedAction]) {
        let current = settings.settings
        var autoRun = 0
        for action in newActions where action.status == .proposed {
            if ApprovalCenter.isAutoApproved(action.kind.risk, settings: current) {
                autoRun += 1
                approveAndRun(action, announce: false)
            }
        }
        let waiting = newActions.count - autoRun
        if waiting > 0 {
            Log.info("AppModel: \(waiting) suggested action(s) waiting in the Inbox.")
        }
        scheduleReload([.actions])
    }

    /// Approves an action and runs it with the executor (Inbox "Approve & run", "Retry").
    func approveAndRun(_ action: ProposedAction) {
        approveAndRun(action, announce: true)
    }

    private func approveAndRun(_ action: ProposedAction, announce: Bool) {
        guard !runningActionIDs.contains(action.id) else { return }
        let storedStatus = db.action(id: action.id)?.status ?? action.status
        switch storedStatus {
        case .proposed, .approved, .failed:
            break
        case .running:
            if announce { showBanner(.info, "“\(action.title)” is already running.") }
            return
        case .done:
            if announce { showBanner(.info, "“\(action.title)” already ran.") }
            return
        case .rejected:
            if announce { showBanner(.info, "“\(action.title)” was dismissed. Restore it first.") }
            return
        }
        var approved = action
        approved.status = .approved
        approved.result = nil
        db.upsertAction(approved)
        replaceLocally(approved)
        EarshotEvents.post(.actions)

        let job = approved
        let executor = self.executor
        runningActionIDs.insert(job.id)
        Log.info("AppModel: running \(job.kind.rawValue) action “\(job.title)”.")
        Task { [weak self] in
            let result = await executor.execute(job)
            guard let self else { return }
            self.runningActionIDs.remove(job.id)
            self.scheduleReload([.actions], delay: 0)
            if result.success {
                Log.info("AppModel: action “\(job.title)” done: \(result.message)")
                if announce { self.showBanner(.success, result.message.nilIfEmpty ?? "Done: \(job.title)") }
            } else {
                Log.error("AppModel: action “\(job.title)” failed: \(result.message)")
                self.showBanner(.error, "“\(job.title)” failed: \(result.message)")
            }
        }
    }

    func reject(_ action: ProposedAction) {
        var rejected = db.action(id: action.id) ?? action
        guard rejected.status != .running else { return }
        rejected.status = .rejected
        db.upsertAction(rejected)
        replaceLocally(rejected)
        EarshotEvents.post(.actions)
    }

    /// Moves a dismissed action back to the Inbox suggestions.
    func restore(_ action: ProposedAction) {
        var restored = db.action(id: action.id) ?? action
        restored.status = .proposed
        restored.result = nil
        restored.executedAt = nil
        db.upsertAction(restored)
        replaceLocally(restored)
        EarshotEvents.post(.actions)
    }

    /// Saves an edited suggestion (title / payload).
    func updateAction(_ action: ProposedAction) {
        db.upsertAction(action)
        replaceLocally(action)
        EarshotEvents.post(.actions)
    }

    /// "Add to Reminders" from an insight.
    func createReminder(from insight: Insight) {
        let payload = ActionPayload(notes: insight.detail.nilIfEmpty,
                                    dueISO: insight.dueAt.map { DateParsing.isoLocal($0) })
        let action = ProposedAction.make(kind: .reminder, title: insight.title,
                                         rationale: "Added from Today by you.", payload: payload,
                                         sourceInsightID: insight.id)
        db.upsertAction(action)
        EarshotEvents.post(.actions)
        approveAndRun(action, announce: true)
    }

    private func replaceLocally(_ action: ProposedAction) {
        if let index = actions.firstIndex(where: { $0.id == action.id }) {
            actions[index] = action
        } else {
            actions.insert(action, at: 0)
        }
    }

    // MARK: - Insights

    func setStatus(_ status: InsightStatus, for insight: Insight) {
        var updated = db.insight(id: insight.id) ?? insight
        updated.status = status
        db.upsertInsight(updated)
        if let index = insights.firstIndex(where: { $0.id == updated.id }) {
            insights[index] = updated
        }
        EarshotEvents.post(.insights)
    }

    // MARK: - Prompts

    func answer(_ prompt: StoredPrompt, choiceID: String) {
        submit(PromptAnswer(promptID: prompt.id, mode: .choice, choiceID: choiceID, text: nil, answeredAt: Date()))
    }

    func answer(_ prompt: StoredPrompt, text: String) {
        guard let reply = text.nilIfEmpty else { return }
        submit(PromptAnswer(promptID: prompt.id, mode: .text, choiceID: nil, text: reply, answeredAt: Date()))
    }

    func dismiss(_ prompt: StoredPrompt) {
        submit(PromptAnswer(promptID: prompt.id, mode: .dismissed, answeredAt: Date()))
    }

    func snooze(_ prompt: StoredPrompt) {
        submit(PromptAnswer(promptID: prompt.id, mode: .snoozed, answeredAt: Date()))
    }

    private func submit(_ answer: PromptAnswer) {
        let scheduler = self.scheduler
        Task { [weak self] in
            await scheduler.handleAnswer(answer)
            self?.scheduleReload([.prompts, .goals, .actions, .insights], delay: 0)
        }
    }

    /// Releases a queued question to the watch right away, bypassing the daily budget.
    func sendToWatchNow(_ prompt: StoredPrompt) {
        var released = prompt
        released.status = .pending
        released.releasedAt = Date()
        released.notBefore = nil
        scheduler.release(released)
        if let index = prompts.firstIndex(where: { $0.id == released.id }) {
            prompts[index] = released
        }
        showBanner(.success, "Sent to your watch. It appears on the next sync.")
    }

    // MARK: - Goals

    @discardableResult
    func createGoal(title: String, why: String) -> Goal? {
        guard let cleanTitle = title.nilIfEmpty else { return nil }
        let goal = Goal.make(title: cleanTitle, why: why.trimmed)
        db.upsertGoal(goal)
        goals.insert(goal, at: 0)
        EarshotEvents.post(.goals)
        return goal
    }

    func saveGoal(_ goal: Goal) {
        db.upsertGoal(goal)
        if let index = goals.firstIndex(where: { $0.id == goal.id }) {
            goals[index] = goal
        }
        EarshotEvents.post(.goals)
    }

    func deleteGoal(_ goal: Goal) {
        db.deleteGoal(id: goal.id)
        goals.removeAll { $0.id == goal.id }
        EarshotEvents.post(.goals)
    }

    func addNote(_ text: String, to goal: Goal) {
        guard let note = text.nilIfEmpty else { return }
        var updated = db.goal(id: goal.id) ?? goal
        updated.notes.append(GoalNote(date: Date(), text: note))
        updated.lastCheckIn = Date()
        saveGoal(updated)
    }

    /// Creates a check-in question about a goal: queued for a good moment, or released now.
    func askAboutGoal(_ goal: Goal, immediately: Bool) {
        let body = goal.why.isEmpty
            ? "How is “\(goal.title)” going? Anything you did toward it, or anything in the way?"
            : "How is “\(goal.title)” going? You said it matters because: \(goal.why.clipped(160))"
        let prompt = StoredPrompt.make(kind: .question, title: goal.title.clipped(60), body: body,
                                       allowsFreeText: true, allowsVoice: true, priority: 3,
                                       status: immediately ? .pending : .queued,
                                       rationale: "You asked Earshot to check in on this goal.",
                                       relatedID: goal.id,
                                       expiresAt: Date().addingTimeInterval(3 * 86_400))
        if immediately {
            scheduler.release(prompt)
            showBanner(.success, "Sent to your watch.")
        } else {
            db.upsertPrompt(prompt)
            EarshotEvents.post(.prompts)
            showBanner(.success, "Earshot will ask you at a good moment.")
        }
    }

    // MARK: - Digests

    func generateDigest(weekly: Bool) {
        guard !isGeneratingDigest else { return }
        refreshAIStatus()
        guard aiConfigured else {
            showBanner(.warning, "Add an Anthropic API key in Settings → AI to generate digests.")
            return
        }
        isGeneratingDigest = true
        digestError = nil
        let engine = digestEngine
        let day = Date()
        Task { [weak self] in
            do {
                let digest: Digest
                if weekly {
                    digest = try await engine.generateWeekly(endingOn: day)
                } else {
                    digest = try await engine.generateDaily(for: day)
                }
                guard let self else { return }
                self.isGeneratingDigest = false
                self.selectedDigestID = digest.day
                if !self.digests.contains(where: { $0.day == digest.day }) {
                    self.digests.insert(digest, at: 0)
                }
                self.scheduleReload([.digests], delay: 0)
                self.showBanner(.success, weekly ? "Weekly review ready." : "Today's digest is ready.")
            } catch {
                Log.error("AppModel: digest generation failed: \(error.localizedDescription)")
                guard let self else { return }
                self.isGeneratingDigest = false
                self.digestError = error.localizedDescription
                self.showBanner(.error, "Digest failed: \(error.localizedDescription)")
            }
        }
    }

    /// Menu bar "Today's digest": shows today's digest, generating it when missing.
    func openTodaysDigest() {
        sidebarSelection = .digests
        let key = Date().dayKey
        if digests.contains(where: { $0.day == key }) || db.digest(day: key) != nil {
            selectedDigestID = key
            scheduleReload([.digests], delay: 0)
        } else {
            generateDigest(weekly: false)
        }
    }

    // MARK: - Memory chat

    func ask(_ question: String) {
        guard let text = question.nilIfEmpty, pendingQuestion == nil else { return }
        pendingQuestion = text
        askError = nil
        let memory = self.memory
        Task { [weak self] in
            do {
                _ = try await memory.ask(text, persist: true)
                self?.pendingQuestion = nil
            } catch {
                Log.error("AppModel: memory chat failed: \(error.localizedDescription)")
                self?.pendingQuestion = nil
                self?.askError = error.localizedDescription
            }
            self?.scheduleReload([.chat], delay: 0)
        }
    }

    func clearChat() {
        db.clearChat()
        chat = []
        askError = nil
        EarshotEvents.post(.chat)
    }

    // MARK: - Agent

    func runAgent(task: String) {
        guard let text = task.nilIfEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            let run = await self.enqueueAgentRun(task: text, origin: .mac)
            if run.status == .failed {
                self.showBanner(.error, "Agent task failed: \(run.finalText.clipped(160))")
            }
        }
    }

    /// Serialises agent runs so only one drives the Mac at a time.
    private func enqueueAgentRun(task: String, origin: AgentOrigin) async -> AgentRun {
        let previous = agentChain
        let agent = self.agent
        agentQueueDepth += 1
        let job = Task<AgentRun, Never> {
            if let previous {
                await previous.value
            }
            return await agent.run(task: task, origin: origin)
        }
        agentChain = Task {
            _ = await job.value
        }
        let run = await job.value
        agentQueueDepth = max(0, agentQueueDepth - 1)
        return run
    }

    // MARK: - Pairing & server

    func regeneratePairingCode() {
        pairing.regenerateCode()
        objectWillChange.send()
    }

    func unpair(_ device: PairedDevice) {
        pairing.unpair(token: device.token)
        devices.removeAll { $0.token == device.token }
        EarshotEvents.post(.devices)
        showBanner(.info, "Unpaired \(device.name).")
    }

    func restartServer() {
        let httpServer = self.server
        httpServer.stop()
        serverRunning = false
        Task { [weak self] in
            // Give the listener a moment to release the port.
            try? await Task.sleep(nanoseconds: 600_000_000)
            do {
                try httpServer.start()
                self?.serverError = nil
                Log.info("AppModel: server restarted on port \(httpServer.port).")
            } catch {
                Log.error("AppModel: server restart failed: \(error.localizedDescription)")
                self?.serverError = error.localizedDescription
            }
            self?.refreshStatus()
        }
    }

    // MARK: - MCP

    /// Settings → Integrations → Rotate: replaces the MCP bearer token; clients need the new one.
    func rotateMCPToken() {
        mcp.rotateToken()
        objectWillChange.send()
        showBanner(.success, "Created a new MCP token. Update it in your MCP clients.")
    }

    // MARK: - Permissions

    @discardableResult
    func requestCalendarAccess() async -> Bool {
        let calendar = self.calendar
        let granted = await calendar.requestAccess()
        permissionsRevision += 1
        if !granted {
            showBanner(.warning, "Calendar access wasn't granted. You can allow it in System Settings → Privacy & Security.")
        }
        return granted
    }

    @discardableResult
    func requestSpeechAccess() async -> Bool {
        let granted = await TranscriberFactory.requestSpeechAuthorization()
        permissionsRevision += 1
        if !granted {
            showBanner(.warning, "Speech recognition wasn't granted. You can allow it in System Settings → Privacy & Security.")
        }
        return granted
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: AppModel.onboardingDefaultsKey)
        refreshAIStatus()
        permissionsRevision += 1
    }

    // MARK: - Mac microphone

    func setMacMicEnabled(_ enabled: Bool) {
        if settings.settings.macMicEnabled != enabled {
            settings.settings.macMicEnabled = enabled
        }
        if enabled {
            guard !micRecorder.isRecording else { return }
            Task { [weak self] in
                guard let self else { return }
                await self.micRecorder.start()
                if self.stopMicIfDisabled() { return }
                if let error = self.micRecorder.lastError, !self.micRecorder.isRecording {
                    self.showBanner(.error, "Mac microphone: \(error)")
                }
            }
        } else if micRecorder.isRecording {
            micRecorder.stop()
        }
    }

    /// `micRecorder.start()` can wait on the microphone prompt; if desk mode was switched off in the
    /// meantime, stops the recording it went on to start. Returns true when desk mode is off.
    @discardableResult
    private func stopMicIfDisabled() -> Bool {
        guard !settings.settings.macMicEnabled else { return false }
        if micRecorder.isRecording {
            micRecorder.stop()
            Log.info("AppModel: desk mode was switched off while the microphone was starting; stopped it.")
        }
        return true
    }

    // MARK: - Import

    func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "Import Audio"
        panel.message = "Choose recordings to transcribe and add to your timeline."
        panel.prompt = "Import"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK else { return }
        importAudioFiles(panel.urls)
    }

    /// Imports local audio files (open panel or drag & drop) through the pipeline.
    func importAudioFiles(_ urls: [URL]) {
        let audioURLs = urls.filter { AppModel.isAudioFile($0) }
        let skipped = urls.count - audioURLs.count
        guard !audioURLs.isEmpty else {
            showBanner(.warning, "Those files don't look like audio recordings.")
            return
        }
        importsInProgress += audioURLs.count
        let pipeline = self.pipeline
        Task { [weak self] in
            var accepted = 0
            var failures: [String] = []
            for url in audioURLs {
                let outcome = await Task.detached(priority: .userInitiated) { () async -> ImportOutcome in
                    let meta = await AppModel.importMeta(for: url)
                    let ack = pipeline.ingestFile(at: url, meta: meta, move: false)
                    return ImportOutcome(accepted: ack.accepted, message: ack.message)
                }.value
                if outcome.accepted {
                    accepted += 1
                    Log.info("AppModel: imported \(url.lastPathComponent).")
                } else {
                    let reason = outcome.message ?? "rejected"
                    failures.append("\(url.lastPathComponent): \(reason)")
                    Log.error("AppModel: import of \(url.lastPathComponent) failed: \(reason)")
                }
                self?.importsInProgress = max(0, (self?.importsInProgress ?? 1) - 1)
            }
            guard let self else { return }
            self.scheduleReload([.segments, .utterances], delay: 0)
            if failures.isEmpty {
                var text = accepted == 1 ? "Imported 1 recording. Transcribing…" : "Imported \(accepted) recordings. Transcribing…"
                if skipped > 0 { text += " Skipped \(skipped) non-audio file(s)." }
                self.showBanner(.success, text)
            } else {
                self.showBanner(.error, "Imported \(accepted) of \(audioURLs.count). \(failures.first ?? "")")
            }
        }
    }

    private struct ImportOutcome: Sendable {
        var accepted: Bool
        var message: String?
    }

    nonisolated private static func isAudioFile(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return false }
        return type.conforms(to: .audio)
    }

    nonisolated private static func importMeta(for url: URL) async -> SegmentMeta {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let startedAt = values?.creationDate ?? values?.contentModificationDate ?? Date()
        var duration: Double = 0
        let asset = AVURLAsset(url: url)
        do {
            let time = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(time)
            if seconds.isFinite && seconds > 0 { duration = seconds }
        } catch {
            Log.info("AppModel: could not read the duration of \(url.lastPathComponent): \(error.localizedDescription)")
        }
        return SegmentMeta(id: UUID().uuidString, device: "import", startedAt: startedAt, duration: duration,
                           avgPower: -20, peakPower: -5, speechRatio: 1, reason: .stopped)
    }

    // MARK: - Data

    /// "Forget this": deletes the transcript and the recorded audio of a time range. Utterances that
    /// overlap the range are deleted whole, and so is the audio of every segment that overlaps it.
    /// Segments still waiting for transcription (or still on the watch) are scrubbed once they are
    /// transcribed (or stored as silent, or fail), so their speech outside the range is kept.
    func forget(from: Date, to: Date) {
        guard to > from else { return }
        rememberForgottenRange(from: from, to: to)
        let removedAudio = scrub(from: from, to: to)
        utterances.removeAll { AppModel.isForgotten($0, from: from, to: to) }
        EarshotEvents.post(.utterances)
        if removedAudio > 0 { EarshotEvents.post(.segments) }
        Log.info("AppModel: forgot \(from.shortText) – \(to.shortText) (transcript and the audio of \(removedAudio) segment(s)).")
        showBanner(.success, "Forgot \(from.timeText)–\(to.timeText).")
    }

    /// The rule `scrub(from:to:)` deletes by: the utterance starts in the range, or starts before it
    /// and runs into it.
    nonisolated private static func isForgotten(_ utterance: Utterance, from: Date, to: Date) -> Bool {
        utterance.startedAt < to && (utterance.startedAt >= from || utterance.endedAt > from)
    }

    /// Deletes the utterances overlapping [from, to) and the stored audio of the segments overlapping
    /// it, except segments still waiting for (or in) transcription. Returns the number of audio files deleted.
    @discardableResult
    private func scrub(from: Date, to: Date) -> Int {
        // `deleteUtterances` matches on start times only. An utterance that began shortly before the
        // range and runs into it is deleted on its own: a ±0.5 ms window around its stored start.
        let straddling = db.utterances(from: from.addingTimeInterval(-AppModel.forgetUtteranceLookback),
                                       to: from, limit: 5_000)
            .filter { AppModel.isForgotten($0, from: from, to: to) }
        for utterance in straddling {
            db.deleteUtterances(from: utterance.startedAt.addingTimeInterval(-0.0005),
                                to: utterance.startedAt.addingTimeInterval(0.0005))
        }
        db.deleteUtterances(from: from, to: to)

        let fileManager = FileManager.default
        var removed = 0
        let candidates = db.segments(from: from.addingTimeInterval(-AppModel.forgetSegmentLookback), to: to)
        for var segment in candidates where segment.endedAt > from {
            guard let path = segment.filePath else { continue }
            switch segment.status {
            case .received, .transcribing:
                // Deleting it now would fail its transcription; `scrubIfForgotten` handles it afterwards.
                continue
            case .transcribed, .silent, .failed:
                break
            }
            if fileManager.fileExists(atPath: path) {
                do {
                    try fileManager.removeItem(atPath: path)
                } catch {
                    Log.error("AppModel: could not delete the audio of segment \(segment.id): \(error.localizedDescription)")
                    continue
                }
            }
            segment.filePath = nil
            db.upsertSegment(segment)
            removed += 1
        }
        return removed
    }

    /// Re-applies recent forget requests to a segment that was transcribed, stored as silent or
    /// marked failed after them.
    private func scrubIfForgotten(_ segment: Segment) {
        let ranges = loadForgottenRanges().filter { $0.from < segment.endedAt && $0.to > segment.startedAt }
        guard !ranges.isEmpty else { return }
        var removedAudio = 0
        for range in ranges {
            removedAudio += scrub(from: range.from, to: range.to)
        }
        utterances.removeAll { utterance in
            ranges.contains { AppModel.isForgotten(utterance, from: $0.from, to: $0.to) }
        }
        EarshotEvents.post(.utterances)
        if removedAudio > 0 { EarshotEvents.post(.segments) }
        Log.info("AppModel: segment \(segment.id) overlaps \(ranges.count) forgotten range(s); scrubbed it.")
    }

    private func loadForgottenRanges() -> [ForgottenRange] {
        if let cached = forgottenRanges { return cached }
        var loaded: [ForgottenRange] = []
        if let raw = db.kvGet(AppModel.forgottenRangesKey) {
            if let decoded = try? JSONDecoder().decode([ForgottenRange].self, from: Data(raw.utf8)) {
                loaded = decoded
            } else {
                Log.error("AppModel: could not read the forgotten time ranges; starting afresh.")
            }
        }
        let cutoff = Date().addingTimeInterval(-AppModel.forgottenRangeLifetime)
        loaded.removeAll { $0.at < cutoff }
        forgottenRanges = loaded
        return loaded
    }

    private func rememberForgottenRange(from: Date, to: Date) {
        let now = Date()
        let cutoff = now.addingTimeInterval(-AppModel.forgottenRangeLifetime)
        var ranges = loadForgottenRanges().filter { $0.at >= cutoff }
        ranges.append(ForgottenRange(from: from, to: to, at: now))
        if ranges.count > AppModel.forgottenRangeLimit {
            ranges.removeFirst(ranges.count - AppModel.forgottenRangeLimit)
        }
        forgottenRanges = ranges
        do {
            let data = try JSONEncoder().encode(ranges)
            db.kvSet(AppModel.forgottenRangesKey, String(decoding: data, as: UTF8.self))
        } catch {
            Log.error("AppModel: could not save the forgotten time range: \(error.localizedDescription)")
        }
    }

    func searchArchive(_ query: String, limit: Int = 200) async -> [Utterance] {
        guard let text = query.nilIfEmpty else { return [] }
        let db = self.db
        return await Task.detached(priority: .userInitiated) {
            db.searchUtterances(text, limit: limit)
        }.value
    }

    /// Settings → Data → Erase all data. Keeps settings and API keys. The database wipe (a DELETE
    /// on every table plus VACUUM) and the audio deletion run off the main thread.
    func eraseAllData() {
        guard !isErasing else { return }
        isErasing = true
        // Stop AppModel's own passes over the old data so they don't write results after the wipe.
        // (New analysis passes are refused while `isErasing` is set.)
        analysisTask?.cancel()
        digestCheckTask?.cancel()
        clearLoadedData()
        Log.info("AppModel: erasing all data.")

        let db = self.db
        let audioRoot = AppPaths.supportDirectory.appendingPathComponent("Audio", isDirectory: true)
        Task { [weak self] in
            await Task.detached(priority: .userInitiated) {
                db.wipeAll()
                if FileManager.default.fileExists(atPath: audioRoot.path) {
                    do {
                        try FileManager.default.removeItem(at: audioRoot)
                    } catch {
                        Log.error("AppModel: could not delete stored audio: \(error.localizedDescription)")
                    }
                }
            }.value
            guard let self else { return }
            // A reload that ran while the wipe was waiting for the database may have brought old rows back.
            self.clearLoadedData()
            self.handledWatchRequests = nil
            self.forgottenRanges = nil
            self.isErasing = false
            for scope in DataScope.allCases {
                EarshotEvents.post(scope)
            }
            Log.info("AppModel: erased all data.")
            self.showBanner(.success, "All Earshot data was erased.")
        }
    }

    /// Empties every published collection loaded from the database (used by `eraseAllData`).
    private func clearLoadedData() {
        utterances = []
        segments = []
        bookmarks = []
        insights = []
        prompts = []
        actions = []
        goals = []
        digests = []
        devices = []
        chat = []
        dayWordCount = 0
        dayRecordedSeconds = 0
        todayWordCount = 0
        selectedDigestID = nil
        highlightedUtteranceID = nil
    }

    /// Settings → Data → "Export Everything…": asks for a folder, writes an open-format copy of the
    /// archive there (off the main thread), then reveals it in Finder.
    func exportAll() {
        guard !isExporting else {
            showBanner(.info, "An export is already running.")
            return
        }
        guard !isErasing else {
            showBanner(.info, "Earshot is erasing your data. Try again when it has finished.")
            return
        }
        let panel = NSOpenPanel()
        panel.title = "Export Everything"
        panel.message = "Choose where to save the export. Earshot creates a new “Earshot Export” folder there with your transcripts, insights, goals, questions, actions and digests in Markdown and JSON."
        panel.prompt = "Export"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let folder = panel.url else { return }

        isExporting = true
        exportError = nil
        Log.info("AppModel: exporting everything to \(folder.path).")
        let db = self.db
        Task { [weak self] in
            do {
                let exported = try await Task.detached(priority: .userInitiated) {
                    try Exporter.exportAll(db: db, to: folder)
                }.value
                guard let self else { return }
                self.isExporting = false
                self.lastExportURL = exported
                NSWorkspace.shared.activateFileViewerSelecting([exported])
                self.showBanner(.success, "Exported everything to “\(exported.lastPathComponent)”.")
            } catch {
                Log.error("AppModel: export failed: \(error.localizedDescription)")
                guard let self else { return }
                self.isExporting = false
                self.exportError = error.localizedDescription
                self.showBanner(.error, "Export failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Navigation helpers

    func show(date: Date, utteranceID: Int64? = nil) {
        selectedDay = date.startOfDay
        highlightedUtteranceID = utteranceID
        sidebarSelection = .today
    }

    /// Insight "Show in Transcript": opens Today on the insight's source and highlights the utterance
    /// it came from (the first one in its source range, else the one starting nearest to it).
    func showSource(of insight: Insight) {
        guard let source = insight.sourceFrom else { return }
        let end = max(insight.sourceTo ?? source, source)
        let db = self.db
        Task { [weak self] in
            let nearby = await Task.detached(priority: .userInitiated) {
                db.utterances(from: source.addingTimeInterval(-300), to: end.addingTimeInterval(300), limit: 2_000)
            }.value
            guard let self else { return }
            let inside = nearby.first { $0.endedAt >= source && $0.startedAt <= end }
            let target = inside ?? nearby.min { first, second in
                abs(first.startedAt.timeIntervalSince(source)) < abs(second.startedAt.timeIntervalSince(source))
            }
            self.show(date: target?.startedAt ?? source, utteranceID: target?.id)
        }
    }

    func showDigest(_ id: String) {
        selectedDigestID = id
        sidebarSelection = .digests
    }

    // MARK: - WatchBridge

    func watchDidAnswer(_ answer: PromptAnswer, device: PairedDevice) async {
        Log.info("AppModel: answer from \(device.name) for prompt \(answer.promptID) (\(answer.mode.rawValue)).")
        // Interpreting an answer may call the model; reply to the watch right away.
        submit(answer)
    }

    func watchDidRequest(_ request: WatchRequest, device: PairedDevice) async -> WatchRequestAck {
        // The watch keeps a request in its outbox until it gets a response, so one whose response
        // was lost comes back with the same id: send the same acknowledgement again instead of
        // repeating its side effects (a second agent run, answer or note). This runs on the main
        // actor without suspending, so a duplicate cannot slip in between the check and the record.
        if let previous = loadHandledWatchRequests()[request.id] {
            Log.info("AppModel: \(request.kind.rawValue) request \(request.id) from \(device.name) was already handled; acknowledging again.")
            return previous.ack
        }
        let ack = handleWatchRequest(request, device: device)
        if ack.accepted { recordHandledWatchRequest(ack) }
        return ack
    }

    private func loadHandledWatchRequests() -> [String: HandledWatchRequest] {
        if let cached = handledWatchRequests { return cached }
        var loaded: [String: HandledWatchRequest] = [:]
        if let raw = db.kvGet(AppModel.handledWatchRequestsKey) {
            if let decoded = try? JSONDecoder().decode(HandledWatchRequestTable.self, from: Data(raw.utf8)) {
                loaded = decoded
            } else {
                Log.error("AppModel: could not read the handled watch requests; starting afresh.")
            }
        }
        handledWatchRequests = loaded
        return loaded
    }

    private func recordHandledWatchRequest(_ ack: WatchRequestAck) {
        let now = Date()
        let cutoff = now.addingTimeInterval(-AppModel.handledWatchRequestLifetime)
        var records: [String: HandledWatchRequest] = loadHandledWatchRequests().filter { $0.value.at >= cutoff }
        records[ack.id] = HandledWatchRequest(ack: ack, at: now)
        if records.count > AppModel.handledWatchRequestLimit {
            let newest = records.sorted { $0.value.at > $1.value.at }.prefix(AppModel.handledWatchRequestLimit)
            records = Dictionary(newest.map { ($0.key, $0.value) }, uniquingKeysWith: { first, _ in first })
        }
        handledWatchRequests = records
        do {
            let data = try JSONEncoder().encode(records)
            db.kvSet(AppModel.handledWatchRequestsKey, String(decoding: data, as: UTF8.self))
        } catch {
            Log.error("AppModel: could not save the handled watch requests: \(error.localizedDescription)")
        }
    }

    private func handleWatchRequest(_ request: WatchRequest, device: PairedDevice) -> WatchRequestAck {
        let requestID = request.id
        guard let text = request.text.nilIfEmpty else {
            return WatchRequestAck(id: requestID, accepted: false, message: "I didn't catch that. Try again.")
        }
        Log.info("AppModel: \(request.kind.rawValue) request from \(device.name): \(text.clipped(80))")

        switch request.kind {
        case .note:
            let lower = text.lowercased()
            let kind: InsightKind = lower.hasPrefix("idea") ? .idea : .fact
            let insight = Insight(id: UUID().uuidString, kind: kind, title: text.clipped(120), detail: text,
                                  dueAt: nil, people: [], sourceFrom: request.createdAt, sourceTo: request.createdAt,
                                  status: .open, confidence: 1, createdAt: Date())
            db.upsertInsight(insight)
            EarshotEvents.post(.insights)
            return WatchRequestAck(id: requestID, accepted: true, message: kind == .idea ? "Idea saved." : "Saved. I'll remember that.")

        case .ask:
            guard llm.isConfigured else {
                return WatchRequestAck(id: requestID, accepted: false,
                                       message: "Add an API key on your Mac (Settings → AI) so I can answer.")
            }
            let memory = self.memory
            let scheduler = self.scheduler
            Task {
                let body: String
                do {
                    let reply = try await memory.ask(text, persist: true)
                    body = reply.text.nilIfEmpty ?? "I couldn't find anything about that."
                } catch {
                    Log.error("AppModel: watch question failed: \(error.localizedDescription)")
                    body = "Sorry, I couldn't answer that: \(error.localizedDescription)"
                }
                let prompt = StoredPrompt.make(kind: .answer, title: "Answer", body: body.clipped(600),
                                               allowsFreeText: false, allowsVoice: false, priority: 3,
                                               status: .pending, rationale: "Reply to “\(text.clipped(80))”",
                                               relatedID: requestID,
                                               expiresAt: Date().addingTimeInterval(86_400))
                scheduler.release(prompt)
            }
            return WatchRequestAck(id: requestID, accepted: true, message: "Thinking…")

        case .command:
            guard llm.isConfigured else {
                return WatchRequestAck(id: requestID, accepted: false,
                                       message: "Add an API key on your Mac (Settings → AI) so I can do that.")
            }
            let busy = agent.isRunning || agentQueueDepth > 0
            let scheduler = self.scheduler
            Task { [weak self] in
                guard let self else { return }
                let run = await self.enqueueAgentRun(task: text, origin: .watch)
                let title: String
                let body: String
                switch run.status {
                case .done:
                    title = "Done"
                    body = run.finalText.nilIfEmpty ?? "Finished “\(text.clipped(60))”."
                case .failed:
                    title = "Couldn't finish"
                    body = run.finalText.nilIfEmpty ?? "The agent stopped with an error."
                case .cancelled:
                    title = "Cancelled"
                    body = "The task “\(text.clipped(60))” was cancelled on the Mac."
                case .running:
                    title = "Still working"
                    body = run.finalText.nilIfEmpty ?? "Still working on “\(text.clipped(60))”."
                }
                let prompt = StoredPrompt.make(kind: .answer, title: title, body: body.clipped(600),
                                               allowsFreeText: false, allowsVoice: false, priority: 3,
                                               status: .pending, rationale: "Result of “\(text.clipped(80))”",
                                               relatedID: requestID,
                                               expiresAt: Date().addingTimeInterval(86_400))
                scheduler.release(prompt)
            }
            return WatchRequestAck(id: requestID, accepted: true,
                                   message: busy ? "Queued on your Mac. I'll tap you when it's done."
                                                 : "On it. I'll tap you when it's done.")
        }
    }

    func watchDidBookmark(_ bookmark: Bookmark, device: PairedDevice) async {
        let stored = StoredBookmark(id: bookmark.id, kind: bookmark.kind, at: bookmark.at,
                                    note: bookmark.note?.nilIfEmpty, device: device.name)
        db.insertBookmark(stored)
        EarshotEvents.post(.status)
        Log.info("AppModel: \(bookmark.kind.rawValue) from \(device.name) at \(bookmark.at.timeText).")
    }

    /// Nonisolated, so it runs off the main actor: every watch asks for it on each /sync (about once
    /// a minute while recording) and it runs several SQLite queries plus an EventKit lookup.
    nonisolated func todaySnapshot() async -> TodaySnapshot {
        TodayBuilder.snapshot(db: db)
    }
}

// MARK: - Helpers

/// Keeps the first occurrence of every id, preserving order.
private func uniqueByID<T: Identifiable>(_ items: [T]) -> [T] {
    var seen = Set<T.ID>()
    var result: [T] = []
    result.reserveCapacity(items.count)
    for item in items where seen.insert(item.id).inserted {
        result.append(item)
    }
    return result
}
