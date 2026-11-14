//  AudioCapture.swift
//  Earshot (watchOS)
//
//  Always-on recorder. One AVAudioEngine input tap runs continuously (so the
//  microphone never has to be restarted while the app is in the background);
//  only the output file rotates every `segmentSeconds`. Buffers are copied off
//  the tap thread, metered, converted to 16 kHz mono and written to AAC (.m4a)
//  on a private serial queue. Finished files are handed to SegmentQueue.

import AVFoundation
import Combine
import Foundation
import WatchKit

enum RecorderState: Equatable {
    case idle
    case recording
    /// Privacy pause; `nil` means "until I resume".
    case paused(until: Date?)
    /// A call, Siri or the system stopped the microphone; the user must reopen the app.
    case interrupted
    case error(String)
}

/// Returned by `beginVoiceWindow()`; hand it back to `endVoiceWindow(_:)` or `cancelVoiceWindow(_:)`.
/// Only the token of the open window has an effect (a stale one is ignored).
struct VoiceWindowToken {
    fileprivate let id = UUID()
    fileprivate let previous: RecorderState
    fileprivate let temporary: Bool
}

private struct FinishedSegment: @unchecked Sendable {
    let url: URL
    let meta: SegmentMeta
}

private enum CaptureError: LocalizedError {
    case noMicrophone

    var errorDescription: String? {
        switch self {
        case .noMicrophone:
            return "No microphone input is available."
        }
    }
}

/// Battery samples taken while recording (sliding 60-minute window, in memory only)
/// and the drain rate they imply, by least-squares regression.
private struct BatteryDrainWindow {
    struct Sample {
        let date: Date
        /// 0…100
        let percent: Double
    }

    static let interval: TimeInterval = 5 * 60
    static let span: TimeInterval = 60 * 60
    static let minimumSpan: TimeInterval = 15 * 60
    /// A longer gap means sampling stopped (stop, pause, interruption): start over.
    static let maximumGap: TimeInterval = 12 * 60
    /// Below this (percentage points per hour) the rate is noise; no forecast.
    static let minimumDrain: Double = 0.5

    private(set) var samples: [Sample] = []

    var latest: Sample? { samples.last }

    var coveredSeconds: TimeInterval {
        guard let first = samples.first, let last = samples.last else { return 0 }
        return last.date.timeIntervalSince(first.date)
    }

    func isDue(at now: Date) -> Bool {
        guard let last = samples.last else { return true }
        // A little slack so the one-minute ticker doesn't push samples to 6 minutes.
        return now.timeIntervalSince(last.date) >= BatteryDrainWindow.interval - 10
    }

    mutating func add(percent: Double, at date: Date) {
        if let last = samples.last {
            let gap = date.timeIntervalSince(last.date)
            if gap < 0 || gap > BatteryDrainWindow.maximumGap { samples.removeAll() }
        }
        samples.append(Sample(date: date, percent: percent))
        samples.removeAll { date.timeIntervalSince($0.date) > BatteryDrainWindow.span }
    }

    mutating func reset() {
        samples.removeAll()
    }

    /// Percentage points lost per hour (positive while draining); nil until the
    /// samples cover at least 15 minutes.
    var drainPerHour: Double? {
        guard samples.count >= 3, let first = samples.first,
              coveredSeconds >= BatteryDrainWindow.minimumSpan else { return nil }
        let hours = samples.map { $0.date.timeIntervalSince(first.date) / 3600 }
        let count = Double(samples.count)
        let meanX = hours.reduce(0, +) / count
        let meanY = samples.reduce(0.0) { $0 + $1.percent } / count
        var covariance = 0.0
        var variance = 0.0
        for index in samples.indices {
            let dx = hours[index] - meanX
            covariance += dx * (samples[index].percent - meanY)
            variance += dx * dx
        }
        guard variance > 0 else { return nil }
        let drain = -covariance / variance
        return drain.isFinite ? drain : nil
    }
}

// MARK: - AudioCapture

@MainActor
final class AudioCapture: ObservableObject {
    @Published private(set) var state: RecorderState = .idle {
        didSet { recordingStateChanged(from: oldValue) }
    }
    /// dBFS of the latest buffer (-160…0), for the level bar.
    @Published private(set) var level: Float = -160
    /// Seconds recorded into the current segment.
    @Published private(set) var segmentElapsed: TimeInterval = 0
    /// Seconds in finished segments today (resets at midnight).
    @Published private(set) var recordedSecondsToday: Double = 0
    @Published private(set) var lastSegmentAt: Date? = nil
    /// The user's intent; survives relaunches.
    @Published private(set) var wantsRecording = false
    @Published private(set) var isInVoiceWindow = false
    /// Latest problem worth showing without changing the state (e.g. a failed resume).
    @Published private(set) var notice: String? = nil
    /// Start of the current continuous stretch of recording; nil when not recording.
    @Published private(set) var recordingSince: Date? = nil
    /// Measured battery drain while recording, in percentage points per hour. Nil until
    /// the samples cover 15 minutes, and while the watch charges.
    @Published private(set) var batteryDrainPerHour: Double? = nil
    /// When recording is expected to stop for low battery (`lowBatteryStopLevel`, else 0 %)
    /// if the measured drain rate holds. Nil when unknown.
    @Published private(set) var batteryForecastEnd: Date? = nil

    /// Receives every finished, non-silent segment (the file is closed and ready to move).
    var onSegment: (@MainActor (URL, SegmentMeta) -> Void)?
    /// Receives privacy-pause bookmarks.
    var onBookmark: (@MainActor (Bookmark) -> Void)?

    var isRecording: Bool { state == .recording }

    var isPrivacyPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    var pausedUntil: Date? {
        if case .paused(let until) = state { return until }
        return nil
    }

    var todayTotalSeconds: Double {
        recordedSecondsToday + (isRecording ? segmentElapsed : 0)
    }

    /// "Recording since 9:12 AM", while recording.
    var recordingSinceText: String? {
        guard isRecording, let since = recordingSince else { return nil }
        return "Recording since \(EarshotFormat.time(since))"
    }

    /// "≈ 5 h 20 m left at this rate", once the drain rate is measured.
    func batteryForecastText(now: Date) -> String? {
        guard isRecording, let end = batteryForecastEnd else { return nil }
        let remaining = end.timeIntervalSince(now)
        guard remaining > 0 else { return nil }
        return "≈ \(AudioCapture.hoursAndMinutes(remaining)) left at this rate"
    }

    /// Battery glide path (lite): at the measured rate, recording would stop before 9 PM today.
    func batteryRunsOutBeforeEvening(now: Date) -> Bool {
        guard isRecording, let end = batteryForecastEnd, end > now,
              let evening = Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: now),
              now < evening else { return false }
        return end < evening
    }

    private enum Keys {
        static let wantsRecording = "audio.wantsRecording"
        static let isPaused = "audio.isPaused"
        static let pausedUntil = "audio.pausedUntil"
        static let recordedDay = "audio.recordedDay"
        static let recordedSeconds = "audio.recordedSeconds"
        static let lastSegmentAt = "audio.lastSegmentAt"
        static let resumeReminderSent = "audio.resumeReminderSent"
    }

    private enum NoticeID {
        static let resume = "earshot.resume"
        static let pauseOver = "earshot.pause-over"
        static let lowBattery = "earshot.low-battery"
    }

    /// A voice window nobody closed (its screen went away) is discarded after this long.
    private static let voiceWindowLimit: TimeInterval = 60
    /// After an automatic start failed, the one-minute check waits this long before trying again.
    private static let automaticRetryInterval: TimeInterval = 5 * 60

    private var engine = AVAudioEngine()
    private let writer: SegmentWriter
    private var settings: RemoteWatchSettings
    private var recordedDay: String
    private var tapInstalled = false
    private var isStarting = false
    private var isForeground = false
    private var pauseTimer: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var voiceWindowID: UUID?
    private var voiceWindowWatchdog: Task<Void, Never>?
    private var lastAutomaticStartFailure: Date?
    private var batteryWindow = BatteryDrainWindow()
    private var batteryWasCharging = false

    init(deviceName: String, settings: RemoteWatchSettings) {
        let defaults = UserDefaults.standard
        let today = AudioCapture.dayKey(Date())
        self.settings = settings
        writer = SegmentWriter(directory: WatchPaths.recording, device: deviceName)
        recordedDay = today

        if defaults.string(forKey: Keys.recordedDay) == today {
            recordedSecondsToday = defaults.double(forKey: Keys.recordedSeconds)
        } else {
            defaults.set(today, forKey: Keys.recordedDay)
            defaults.set(0.0, forKey: Keys.recordedSeconds)
        }
        lastSegmentAt = defaults.object(forKey: Keys.lastSegmentAt) as? Date
        wantsRecording = defaults.bool(forKey: Keys.wantsRecording)
        if wantsRecording {
            if defaults.bool(forKey: Keys.isPaused) {
                state = .paused(until: defaults.object(forKey: Keys.pausedUntil) as? Date)
            } else {
                // Recording was on when the app last ran; it resumes when the app is opened.
                state = .interrupted
            }
        }

        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        writer.update(segmentSeconds: Double(settings.segmentSeconds), silenceThreshold: settings.silenceThresholdDB)
        connectWriter()
        observeAudioSession()
        if let until = pausedUntil { schedulePauseTimer(until) }
    }

    // MARK: Public control

    /// Starts (or resumes) recording. Must be called while the app is in the foreground.
    func start() async {
        await startRecording(automatic: false)
    }

    func resume() async {
        await startRecording(automatic: false)
    }

    /// `automatic`: the app started it (activation, pause expiry), not a tap. A failure
    /// that repeats the previous one then stays quiet (no haptic every minute).
    @discardableResult
    private func startRecording(automatic: Bool) async -> Bool {
        let wasPaused = isPrivacyPaused
        guard await beginCapture(temporary: false, automatic: automatic) else {
            if automatic { lastAutomaticStartFailure = Date() }
            return false
        }
        lastAutomaticStartFailure = nil
        setWantsRecording(true)
        if wasPaused { endPrivacyPause() }
        LocalNotifier.cancel([NoticeID.resume, NoticeID.lowBattery])
        UserDefaults.standard.set(false, forKey: Keys.resumeReminderSent)
        notice = nil
        Haptics.start()
        WatchLog.info("Recording started")
        return true
    }

    /// Stops recording and clears the intent to record.
    func stop() {
        let wasPaused = isPrivacyPaused
        setWantsRecording(false)
        stopEngine()
        finishSegment(reason: .stopped, stopAccepting: true)
        deactivateSession()
        if wasPaused { endPrivacyPause() }
        state = .idle
        level = -160
        notice = nil
        LocalNotifier.cancel([NoticeID.resume])
        Haptics.stop()
        WatchLog.info("Recording stopped by the user (\(drainLogText))")
    }

    /// Privacy pause for `duration` seconds, or until resumed when nil.
    func pause(for duration: TimeInterval?) {
        switch state {
        case .recording, .interrupted, .paused:
            break
        case .idle, .error:
            return
        }
        let alreadyPaused = isPrivacyPaused
        let until = duration.map { Date().addingTimeInterval($0) }
        if state == .recording {
            stopEngine()
            finishSegment(reason: .paused, stopAccepting: true)
        }
        deactivateSession()
        setWantsRecording(true)
        state = .paused(until: until)
        level = -160
        notice = nil

        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Keys.isPaused)
        if let until {
            defaults.set(until, forKey: Keys.pausedUntil)
        } else {
            defaults.removeObject(forKey: Keys.pausedUntil)
        }

        LocalNotifier.cancel([NoticeID.resume, NoticeID.pauseOver])
        if let until {
            LocalNotifier.post(id: NoticeID.pauseOver, title: "Privacy pause over",
                               body: "Tap to resume recording.",
                               category: LocalNotifier.resumeCategory, after: until.timeIntervalSinceNow)
            schedulePauseTimer(until)
        } else {
            pauseTimer?.cancel()
            pauseTimer = nil
        }
        if !alreadyPaused {
            let note = until.map { "Paused until \(EarshotFormat.time($0))" } ?? "Paused until resumed"
            onBookmark?(Bookmark(kind: .privacyPauseStart, note: note))
        }
        Haptics.stop()
        let detail = until.map { EarshotFormat.time($0) } ?? "resumed"
        WatchLog.info("Privacy pause until \(detail)")
    }

    /// Closes the current file immediately (the microphone keeps running).
    func forceRotate(reason: SegmentReason) {
        guard state == .recording else { return }
        finishSegment(reason: reason, stopAccepting: false)
    }

    /// Recording preferences pushed by the Mac.
    func apply(_ newSettings: RemoteWatchSettings) {
        guard newSettings != settings else { return }
        settings = newSettings
        writer.update(segmentSeconds: Double(newSettings.segmentSeconds),
                      silenceThreshold: newSettings.silenceThresholdDB)
        checkBattery()
        refreshBatteryForecast()   // the stop level may have changed
    }

    func setForeground(_ active: Bool) {
        isForeground = active
        // The level bar needs 4 updates a second; in the background only the elapsed time matters.
        writer.setReportsLevels(active)
        if !active { level = -160 }
    }

    /// Auto-resume when the app comes to the front.
    func appBecameActive() async {
        rollDayIfNeeded()
        guard wantsRecording, !isInVoiceWindow, !isStarting else { return }
        switch state {
        case .recording:
            return
        case .paused(let until):
            if let until, until.timeIntervalSinceNow <= 0 { await startRecording(automatic: true) }
        case .interrupted, .error, .idle:
            await startRecording(automatic: true)
        }
    }

    /// Called every minute: midnight reset, battery, pause expiry.
    func periodicCheck() {
        rollDayIfNeeded()
        checkBattery()
        sampleBatteryIfDue()
        if isForeground, !isStarting, automaticRetryAllowed,
           case .paused(let until?) = state, until.timeIntervalSinceNow <= 0 {
            Task { await self.startRecording(automatic: true) }
        }
    }

    /// False for a few minutes after an automatic start failed (low battery, microphone busy).
    private var automaticRetryAllowed: Bool {
        guard let failed = lastAutomaticStartFailure else { return true }
        return Date().timeIntervalSince(failed) >= AudioCapture.automaticRetryInterval
    }

    /// When the app runs in the background while it should be recording but cannot
    /// (e.g. it was relaunched for a background refresh), remind the user once.
    func remindToResumeIfNeeded() {
        guard wantsRecording else { return }
        switch state {
        case .interrupted, .error:
            break
        case .idle, .recording, .paused:
            return
        }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Keys.resumeReminderSent) else { return }
        defaults.set(true, forKey: Keys.resumeReminderSent)
        LocalNotifier.post(id: NoticeID.resume, title: "Earshot isn't recording",
                           body: "Recording stopped while the app was in the background — open Earshot to resume.",
                           category: LocalNotifier.resumeCategory)
    }

    // MARK: Voice answers

    /// Makes sure the microphone is running for a spoken answer. If the recorder
    /// was idle or privacy-paused, it is started temporarily. Returns nil when the
    /// microphone can't be started.
    func beginVoiceWindow() async -> VoiceWindowToken? {
        guard !isInVoiceWindow else { return nil }
        let previous = state
        if state == .recording {
            return openVoiceWindow(VoiceWindowToken(previous: previous, temporary: false))
        }
        guard await beginCapture(temporary: true, automatic: false) else { return nil }
        WatchLog.info("Microphone started for a voice answer")
        return openVoiceWindow(VoiceWindowToken(previous: previous, temporary: true))
    }

    /// Closes the segment holding the spoken answer (so it uploads right away) and
    /// returns the recorder to the state it was in before the window.
    func endVoiceWindow(_ token: VoiceWindowToken) {
        guard closeVoiceWindow(token) else { return }
        guard token.temporary else {
            forceRotate(reason: .voiceAnswer)
            return
        }
        let keepRecording: Bool
        switch token.previous {
        case .paused(let until):
            keepRecording = until.map { $0.timeIntervalSinceNow <= 0 } ?? false
        case .interrupted, .error:
            keepRecording = wantsRecording
        case .recording:
            keepRecording = true
        case .idle:
            keepRecording = false
        }
        if keepRecording && state == .recording {
            forceRotate(reason: .voiceAnswer)
            if case .paused = token.previous { endPrivacyPause() }
            setWantsRecording(true)
            LocalNotifier.cancel([NoticeID.resume])
            notice = nil
            return
        }
        stopEngine()
        finishSegment(reason: .voiceAnswer, stopAccepting: true)
        deactivateSession()
        state = restoredState(token.previous)
        level = -160
    }

    /// The window was abandoned: a temporary capture is discarded unheard.
    func cancelVoiceWindow(_ token: VoiceWindowToken) {
        guard closeVoiceWindow(token) else { return }
        guard token.temporary else { return }
        stopEngine()
        if let discarded = writer.end(reason: .voiceAnswer) {
            try? FileManager.default.removeItem(at: discarded.url)
        }
        deactivateSession()
        state = restoredState(token.previous)
        level = -160
        segmentElapsed = 0
    }

    private func openVoiceWindow(_ token: VoiceWindowToken) -> VoiceWindowToken {
        isInVoiceWindow = true
        voiceWindowID = token.id
        voiceWindowWatchdog?.cancel()
        voiceWindowWatchdog = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(AudioCapture.voiceWindowLimit * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.voiceWindowTimedOut(token)
        }
        return token
    }

    /// Returns false when `token` is not the open window (already closed or timed out).
    private func closeVoiceWindow(_ token: VoiceWindowToken) -> Bool {
        guard voiceWindowID == token.id else { return false }
        voiceWindowID = nil
        isInVoiceWindow = false
        voiceWindowWatchdog?.cancel()
        voiceWindowWatchdog = nil
        return true
    }

    /// Safety net: a window whose screen went away without closing it must not keep the
    /// microphone on (or block battery checks and auto-resume) until the app is relaunched.
    private func voiceWindowTimedOut(_ token: VoiceWindowToken) {
        guard voiceWindowID == token.id else { return }
        WatchLog.error("A voice window was never closed; discarding it")
        cancelVoiceWindow(token)
    }

    private func restoredState(_ previous: RecorderState) -> RecorderState {
        switch previous {
        case .recording, .interrupted:
            return wantsRecording ? .interrupted : .idle
        case .idle, .paused, .error:
            return previous
        }
    }

    // MARK: Engine

    private func beginCapture(temporary: Bool, automatic: Bool) async -> Bool {
        if state == .recording { return true }
        guard !isStarting else { return false }
        isStarting = true
        defer { isStarting = false }

        guard await microphonePermission() else {
            report("Microphone access is off. Allow it in Settings › Privacy & Security › Microphone.",
                   automatic: automatic)
            return false
        }
        if !temporary, let message = batteryBlockMessage() {
            report(message, automatic: automatic)
            return false
        }
        do {
            try startEngine()
        } catch {
            WatchLog.error("Couldn't start recording: \(error.localizedDescription)")
            report("Couldn't start the microphone (\(error.localizedDescription)). Open Earshot and try again.",
                   automatic: automatic)
            return false
        }
        state = .recording
        return true
    }

    /// Activates the audio session and starts the engine. On failure nothing is left
    /// half-started: an active session without a running engine would keep other apps'
    /// audio interrupted while nothing is recorded.
    private func startEngine() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            // Mixable play-and-record: `.record` silences virtually all system output while
            // the session is active (all day here), and a non-mixable session stops other
            // apps' audio and is interrupted whenever one of them starts playing. No
            // Bluetooth options, so the built-in microphone stays the input.
            try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers])
        } catch {
            WatchLog.error("Mixable recording unavailable (\(error.localizedDescription)); using the record category")
            try session.setCategory(.record, mode: .default, options: [])
        }
        // Otherwise the system mutes this app's haptics and system sounds while it records.
        try? session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        try session.setActive(true, options: [])

        do {
            removeTap()
            if engine.isRunning { engine.stop() }
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError.noMicrophone }

            writer.begin(inputFormat: format)
            writer.installTap(on: input, format: format)
            tapInstalled = true
            engine.prepare()
            try engine.start()
            WatchLog.info("Engine running at \(Int(format.sampleRate)) Hz, \(format.channelCount) channel(s)")
        } catch {
            removeTap()
            if engine.isRunning { engine.stop() }
            finishSegment(reason: .interruption, stopAccepting: true)
            deactivateSession()
            throw error
        }
    }

    private func removeTap() {
        guard tapInstalled else { return }
        engine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    private func stopEngine() {
        removeTap()
        if engine.isRunning { engine.stop() }
    }

    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            WatchLog.info("Audio session deactivation: \(error.localizedDescription)")
        }
    }

    private func microphonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        @unknown default:
            return false
        }
    }

    /// Shows a problem; a paused or interrupted state is kept so nothing is lost.
    /// An automatic attempt that fails the same way as the last one stays quiet.
    private func report(_ message: String, automatic: Bool) {
        let repeated = notice == message
        notice = message
        switch state {
        case .paused, .interrupted:
            break
        case .idle, .recording, .error:
            state = .error(message)
        }
        if isForeground, !(automatic && repeated) { Haptics.failure() }
    }

    private func becomeInterrupted(_ body: String) {
        state = .interrupted
        level = -160
        segmentElapsed = 0
        UserDefaults.standard.set(true, forKey: Keys.resumeReminderSent)
        // The notification alerts the user; haptics only play while the app is in front.
        LocalNotifier.post(id: NoticeID.resume, title: "Recording paused", body: body,
                           category: LocalNotifier.resumeCategory)
        if isForeground { Haptics.warning() }
    }

    // MARK: Segments

    private func finishSegment(reason: SegmentReason, stopAccepting: Bool) {
        let finished = stopAccepting ? writer.end(reason: reason) : writer.rotate(reason: reason)
        if let finished { handleFinished(finished) }
        segmentElapsed = 0
    }

    private func handleFinished(_ segment: FinishedSegment) {
        rollDayIfNeeded()
        recordedSecondsToday += segment.meta.duration
        let defaults = UserDefaults.standard
        defaults.set(recordedSecondsToday, forKey: Keys.recordedSeconds)
        let endedAt = segment.meta.startedAt.addingTimeInterval(segment.meta.duration)
        lastSegmentAt = endedAt
        defaults.set(endedAt, forKey: Keys.lastSegmentAt)

        let silent = settings.skipSilentSegments
            && segment.meta.speechRatio < 0.02
            && segment.meta.reason != .voiceAnswer
        if silent {
            try? FileManager.default.removeItem(at: segment.url)
            WatchLog.info("Skipped silent segment \(segment.meta.id) (\(Int(segment.meta.duration)) s)")
        } else if let onSegment {
            onSegment(segment.url, segment.meta)
        } else {
            WatchLog.error("No queue attached; segment \(segment.meta.id) stays in Recording/ until relaunch")
        }
        // Check the battery on every regular rotation (not while another stop is in progress).
        if segment.meta.reason == .rotation {
            checkBattery()
            sampleBatteryIfDue()
        }
    }

    /// The writer reports every 0.25 s in the foreground and every 10 s in the background
    /// (see `setForeground(_:)`), so the main thread stays idle while the screen is off.
    private func updateMeter(db: Float, elapsed: Double) {
        guard state == .recording else { return }
        if isForeground { level = db }
        segmentElapsed = elapsed
    }

    private func handleWriterFailure(_ message: String) {
        guard state == .recording else { return }
        WatchLog.error("Recording failed: \(message)")
        stopEngine()
        finishSegment(reason: .stopped, stopAccepting: true)
        deactivateSession()
        state = .error(message)
        level = -160
        LocalNotifier.post(id: NoticeID.resume, title: "Recording stopped", body: message,
                           category: LocalNotifier.resumeCategory)
        if isForeground { Haptics.warning() }
    }

    private func connectWriter() {
        writer.setHandlers(SegmentWriter.Handlers(
            level: { [weak self] db, elapsed in
                Task { @MainActor in self?.updateMeter(db: db, elapsed: elapsed) }
            },
            finished: { [weak self] segment in
                Task { @MainActor in self?.handleFinished(segment) }
            },
            failed: { [weak self] message in
                Task { @MainActor in self?.handleWriterFailure(message) }
            }))
    }

    // MARK: Battery & day

    private func checkBattery() {
        guard state == .recording, !isInVoiceWindow else { return }
        let device = WKInterfaceDevice.current()
        let battery = device.batteryLevel
        let threshold = settings.lowBatteryStopLevel
        guard battery >= 0, threshold > 0, battery < threshold,
              !AudioCapture.isCharging(device.batteryState) else { return }

        let percent = Int((battery * 100).rounded())
        state = .error("Stopped at \(percent)% battery to save power. Charge, then tap to record.")
        stopEngine()
        finishSegment(reason: .lowBattery, stopAccepting: true)
        deactivateSession()
        setWantsRecording(false)
        level = -160
        LocalNotifier.post(id: NoticeID.lowBattery, title: "Recording stopped",
                           body: "Battery is at \(percent)%. Earshot stopped recording to save power.",
                           category: LocalNotifier.infoCategory)
        if isForeground { Haptics.warning() }
        WatchLog.info("Stopped recording at \(percent)% battery (\(drainLogText))")
    }

    private func batteryBlockMessage() -> String? {
        let device = WKInterfaceDevice.current()
        let battery = device.batteryLevel
        let threshold = settings.lowBatteryStopLevel
        guard battery >= 0, threshold > 0, battery < threshold,
              !AudioCapture.isCharging(device.batteryState) else { return nil }
        return "Battery is at \(Int((battery * 100).rounded()))%. Charge your watch to record."
    }

    private nonisolated static func isCharging(_ batteryState: WKInterfaceDeviceBatteryState) -> Bool {
        switch batteryState {
        case .charging, .full:
            return true
        case .unplugged, .unknown:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: Battery forecast

    /// Keeps `recordingSince` in step with the state and samples as soon as recording starts.
    private func recordingStateChanged(from previous: RecorderState) {
        let nowRecording = state == .recording
        guard nowRecording != (previous == .recording) else { return }
        if nowRecording {
            recordingSince = Date()
            sampleBatteryIfDue()
        } else {
            recordingSince = nil
        }
    }

    /// Takes a battery sample every 5 minutes while recording and refreshes the forecast.
    /// Charging (or full on the charger) clears the window: those readings say nothing about drain.
    private func sampleBatteryIfDue() {
        guard state == .recording else { return }
        let device = WKInterfaceDevice.current()
        if AudioCapture.isCharging(device.batteryState) {
            if !batteryWasCharging {
                batteryWasCharging = true
                WatchLog.info("Charging; battery forecast paused")
            }
            batteryWindow.reset()
            refreshBatteryForecast()
            return
        }
        batteryWasCharging = false
        let now = Date()
        let level = device.batteryLevel
        guard level >= 0, level <= 1, batteryWindow.isDue(at: now) else { return }
        let percent = Double(level) * 100
        batteryWindow.add(percent: percent, at: now)
        refreshBatteryForecast()

        let covered = Int(batteryWindow.coveredSeconds / 60)
        var line = "Battery \(Int(percent.rounded()))%, \(drainLogText) (\(covered) min of samples)"
        if let forecast = batteryForecastText(now: now) { line += ", \(forecast)" }
        WatchLog.info(line)
    }

    /// Recomputes the drain rate and the time recording would stop for low battery.
    private func refreshBatteryForecast() {
        let measured = batteryWindow.drainPerHour
        var end: Date? = nil
        if let drain = measured, drain >= BatteryDrainWindow.minimumDrain, let latest = batteryWindow.latest {
            let stopPercent = Double(min(max(settings.lowBatteryStopLevel, 0), 1)) * 100
            let usable = latest.percent - stopPercent
            let hours = usable / drain
            if usable > 0, hours.isFinite, hours <= 48 {
                end = latest.date.addingTimeInterval(hours * 3600)
            }
        }
        // Assign only on change: @Published notifies on every set.
        if batteryDrainPerHour != measured { batteryDrainPerHour = measured }
        if batteryForecastEnd != end { batteryForecastEnd = end }
    }

    /// For the log: "drain 9.8%/h" or "drain not measured yet".
    private var drainLogText: String {
        guard let drain = batteryDrainPerHour else { return "drain not measured yet" }
        return String(format: "drain %.1f%%/h", drain)
    }

    /// 19_200 → "5 h 20 m", 2_400 → "40 m" (rounded to 5 minutes, at least 5 m).
    private nonisolated static func hoursAndMinutes(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "?" }
        let minutes = max(5, Int((min(seconds, 100 * 3600) / 300).rounded()) * 5)
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) m" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) m"
    }

    private func rollDayIfNeeded() {
        let today = AudioCapture.dayKey(Date())
        guard today != recordedDay else { return }
        recordedDay = today
        recordedSecondsToday = 0
        let defaults = UserDefaults.standard
        defaults.set(today, forKey: Keys.recordedDay)
        defaults.set(0.0, forKey: Keys.recordedSeconds)
    }

    private nonisolated static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    // MARK: Pause bookkeeping

    private func setWantsRecording(_ value: Bool) {
        wantsRecording = value
        UserDefaults.standard.set(value, forKey: Keys.wantsRecording)
    }

    private func endPrivacyPause() {
        pauseTimer?.cancel()
        pauseTimer = nil
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: Keys.isPaused)
        defaults.removeObject(forKey: Keys.pausedUntil)
        LocalNotifier.cancel([NoticeID.pauseOver])
        onBookmark?(Bookmark(kind: .privacyPauseEnd))
    }

    private func schedulePauseTimer(_ until: Date) {
        pauseTimer?.cancel()
        let delay = max(0, until.timeIntervalSinceNow)
        pauseTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000) + 500_000_000)
            guard !Task.isCancelled else { return }
            await self?.pauseDidExpire()
        }
    }

    private func pauseDidExpire() async {
        guard case .paused(let until?) = state, until.timeIntervalSinceNow <= 1 else { return }
        // In the background the microphone can't start; the scheduled notification
        // brings the user back and the app resumes when it becomes active.
        guard isForeground, !isStarting else { return }
        await startRecording(automatic: true)
    }

    // MARK: Session notifications

    private func observeAudioSession() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: session, queue: .main) { [weak self] note in
            let typeRaw = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
            let optionsRaw = (note.userInfo?[AVAudioSessionInterruptionOptionKey] as? NSNumber)?.uintValue ?? 0
            Task { @MainActor in self?.handleInterruption(typeRaw: typeRaw, optionsRaw: optionsRaw) }
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange,
                                            object: nil, queue: .main) { [weak self] note in
            let sender = note.object.map { ObjectIdentifier($0 as AnyObject) }
            Task { @MainActor in self?.handleConfigurationChange(sender: sender) }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification,
                                            object: session, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleMediaServicesReset() }
        })
    }

    private func handleInterruption(typeRaw: UInt?, optionsRaw: UInt) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }
        switch type {
        case .began:
            guard state == .recording else { return }
            WatchLog.info("Audio session interrupted")
            removeTap()
            finishSegment(reason: .interruption, stopAccepting: true)
            if engine.isRunning { engine.stop() }
            becomeInterrupted("Recording paused by a call or Siri — open Earshot to resume.")
        case .ended:
            guard state == .interrupted, wantsRecording, !isStarting else { return }
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsRaw).contains(.shouldResume)
            do {
                try startEngine()
                state = .recording
                LocalNotifier.cancel([NoticeID.resume])
                UserDefaults.standard.set(false, forKey: Keys.resumeReminderSent)
                WatchLog.info("Recording resumed after the interruption (shouldResume: \(shouldResume))")
            } catch {
                // Expected while in the background: the user has to reopen the app.
                WatchLog.info("Couldn't resume after the interruption: \(error.localizedDescription)")
            }
        @unknown default:
            break
        }
    }

    private func handleConfigurationChange(sender: ObjectIdentifier?) {
        if let sender, sender != ObjectIdentifier(engine) { return }
        guard state == .recording, !engine.isRunning else { return }
        WatchLog.info("Audio configuration changed; restarting the engine")
        removeTap()
        finishSegment(reason: .interruption, stopAccepting: true)
        do {
            try startEngine()
        } catch {
            WatchLog.error("Engine restart failed: \(error.localizedDescription)")
            becomeInterrupted("Recording stopped when the audio setup changed — open Earshot to resume.")
        }
    }

    private func handleMediaServicesReset() {
        let wasRecording = state == .recording
        WatchLog.error("Media services were reset")
        tapInstalled = false   // the old engine and its tap are gone
        if wasRecording { finishSegment(reason: .interruption, stopAccepting: true) }
        engine = AVAudioEngine()
        guard wasRecording else { return }
        do {
            try startEngine()
        } catch {
            becomeInterrupted("Recording stopped after an audio system reset — open Earshot to resume.")
        }
    }
}

// MARK: - SegmentWriter

/// Owns everything that touches audio buffers and files. All mutable state is
/// confined to `queue`; the main actor talks to it with `sync` calls (short)
/// and it reports back through `Handlers`.
private final class SegmentWriter: @unchecked Sendable {
    struct Handlers {
        let level: @Sendable (Float, Double) -> Void
        let finished: @Sendable (FinishedSegment) -> Void
        let failed: @Sendable (String) -> Void
    }

    private enum Pipeline {
        case converted(AVAudioConverter, AVAudioFormat)
        case passthrough
        case native
    }

    private final class OpenSegment {
        let id: String
        let url: URL
        var file: AVAudioFile?
        let startedAt: Date
        let sampleRate: Double
        var native: Bool
        var frames: Int64 = 0
        var dbSum: Double = 0
        var bufferCount = 0
        var speechCount = 0
        var peak: Float = -160
        var writeErrors = 0

        init(id: String, url: URL, file: AVAudioFile?, startedAt: Date, sampleRate: Double, native: Bool) {
            self.id = id
            self.url = url
            self.file = file
            self.startedAt = startedAt
            self.sampleRate = sampleRate
            self.native = native
        }
    }

    private struct BufferItem: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer
        let arrival: Date
    }

    /// Hands one buffer to AVAudioConverter, then reports "no data for now".
    private final class InputFeed {
        private var buffer: AVAudioPCMBuffer?

        init(_ buffer: AVAudioPCMBuffer) {
            self.buffer = buffer
        }

        func take() -> AVAudioPCMBuffer? {
            let next = buffer
            buffer = nil
            return next
        }
    }

    private let queue = DispatchQueue(label: "com.earshot.watch.segment-writer", qos: .userInitiated,
                                      autoreleaseFrequency: .workItem)
    private let directory: URL
    private let device: String

    // Confined to `queue`.
    private var handlers: Handlers?
    private var inputFormat: AVAudioFormat?
    private var pipeline: Pipeline = .native
    private var preferNative = false
    private var accepting = false
    private var reportedFailure = false
    private var segmentSeconds: Double = 120
    private var silenceThreshold: Float = -45
    private var current: OpenSegment?
    private var anchor: Date?
    private var runFrames: Int64 = 0
    private var lastLevelReport = Date.distantPast
    /// 0.25 s while the app is in front, 10 s in the background.
    private var levelInterval: TimeInterval = 10
    private var conversionErrors = 0

    init(directory: URL, device: String) {
        self.directory = directory
        self.device = device
    }

    // MARK: Main-actor API

    func setHandlers(_ handlers: Handlers) {
        queue.sync { self.handlers = handlers }
    }

    func update(segmentSeconds: Double, silenceThreshold: Float) {
        let seconds = min(max(segmentSeconds, 15), 900)
        queue.async {
            self.segmentSeconds = seconds
            self.silenceThreshold = silenceThreshold
        }
    }

    /// Frequent level reports for the meter on screen, or one every 10 s in the background
    /// (each report wakes the main thread).
    func setReportsLevels(_ frequent: Bool) {
        let interval: TimeInterval = frequent ? 0.25 : 10
        queue.async {
            self.levelInterval = interval
            if frequent { self.lastLevelReport = .distantPast }
        }
    }

    /// Prepares a new engine run with the input node's format.
    func begin(inputFormat format: AVAudioFormat) {
        queue.sync {
            self.inputFormat = format
            self.accepting = true
            self.reportedFailure = false
            self.anchor = nil
            self.runFrames = 0
            self.conversionErrors = 0
            self.lastLevelReport = .distantPast
            self.pipeline = self.makePipeline(for: format)
        }
    }

    /// Installs the tap. The closure is created here, outside any actor, because
    /// the engine calls it on its own thread.
    func installTap(on node: AVAudioInputNode, format: AVAudioFormat) {
        node.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.receive(buffer)
        }
    }

    /// Closes the current file (buffers keep flowing into a new one).
    func rotate(reason: SegmentReason) -> FinishedSegment? {
        queue.sync { self.finishCurrent(reason: reason) }
    }

    /// Stops accepting buffers and closes the current file. Buffers already
    /// queued are written first.
    func end(reason: SegmentReason) -> FinishedSegment? {
        queue.sync { () -> FinishedSegment? in
            self.accepting = false
            return self.finishCurrent(reason: reason)
        }
    }

    // MARK: Tap thread

    private func receive(_ buffer: AVAudioPCMBuffer) {
        guard buffer.frameLength > 0, let copy = SegmentWriter.copy(buffer) else { return }
        let item = BufferItem(buffer: copy, arrival: Date())
        queue.async { self.process(item) }
    }

    // MARK: Writer queue

    private func process(_ item: BufferItem) {
        guard accepting, let format = inputFormat, let handlers else { return }
        let buffer = item.buffer
        guard buffer.format.sampleRate == format.sampleRate,
              buffer.format.channelCount == format.channelCount else { return }

        let frames = Int64(buffer.frameLength)
        let bufferSeconds = Double(frames) / format.sampleRate
        if anchor == nil {
            anchor = item.arrival.addingTimeInterval(-bufferSeconds)
            runFrames = 0
        }
        if current == nil {
            openSegment(arrival: item.arrival, bufferSeconds: bufferSeconds, format: format, handlers: handlers)
        }
        guard let segment = current else { return }

        let levels = SegmentWriter.levels(of: buffer)
        segment.bufferCount += 1
        segment.dbSum += Double(levels.rms)
        if levels.rms > silenceThreshold { segment.speechCount += 1 }
        segment.peak = max(segment.peak, levels.peak)

        if write(buffer, to: segment, handlers: handlers) {
            segment.frames += frames
        }
        runFrames += frames

        let elapsed = Double(segment.frames) / segment.sampleRate
        if item.arrival.timeIntervalSince(lastLevelReport) >= levelInterval {
            lastLevelReport = item.arrival
            handlers.level(levels.rms, elapsed)
        }

        if conversionErrors >= 20 {
            // The converter keeps failing: continue with the native-rate encoder.
            WatchLog.error("Audio conversion keeps failing; switching to the native sample rate")
            preferNative = true
            pipeline = .native
            conversionErrors = 0
            if let finished = finishCurrent(reason: .rotation) { handlers.finished(finished) }
            return
        }
        if elapsed >= segmentSeconds, let finished = finishCurrent(reason: .rotation) {
            handlers.finished(finished)
        }
    }

    private func makePipeline(for format: AVAudioFormat) -> Pipeline {
        if preferNative { return .native }
        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000,
                                         channels: 1, interleaved: false) else { return .native }
        if format.sampleRate == 16_000, format.channelCount == 1,
           format.commonFormat == .pcmFormatFloat32, !format.isInterleaved {
            return .passthrough
        }
        guard let converter = AVAudioConverter(from: format, to: target) else {
            WatchLog.error("No converter from \(format) to 16 kHz mono; using the native rate")
            return .native
        }
        converter.downmix = true
        return .converted(converter, target)
    }

    private func openSegment(arrival: Date, bufferSeconds: Double, format: AVAudioFormat, handlers: Handlers) {
        let id = UUID().uuidString
        let url = directory.appendingPathComponent("\(id).m4a")

        // Segments of one engine run form a continuous timeline; re-anchor when the
        // audio clock and the wall clock disagree by more than 2 s.
        let observedStart = arrival.addingTimeInterval(-bufferSeconds)
        var start = (anchor ?? observedStart).addingTimeInterval(Double(runFrames) / format.sampleRate)
        if abs(start.timeIntervalSince(observedStart)) > 2 {
            anchor = observedStart.addingTimeInterval(-Double(runFrames) / format.sampleRate)
            start = observedStart
        }

        var file: AVAudioFile?
        var native = false
        if case .native = pipeline {
            native = true
        } else {
            do {
                file = try AVAudioFile(forWriting: url, settings: SegmentWriter.compactSettings,
                                       commonFormat: .pcmFormatFloat32, interleaved: false)
            } catch {
                WatchLog.error("16 kHz AAC unavailable (\(error.localizedDescription)); using the native rate")
                try? FileManager.default.removeItem(at: url)
                preferNative = true
                pipeline = .native
                native = true
            }
        }
        if native {
            do {
                file = try AVAudioFile(forWriting: url, settings: SegmentWriter.nativeSettings(for: format),
                                       commonFormat: .pcmFormatFloat32, interleaved: false)
            } catch {
                try? FileManager.default.removeItem(at: url)
                fail("Couldn't create an audio file: \(error.localizedDescription)", handlers: handlers)
                return
            }
        }
        current = OpenSegment(id: id, url: url, file: file, startedAt: start,
                              sampleRate: format.sampleRate, native: native)
    }

    /// Returns true when the buffer's audio is in the file.
    private func write(_ buffer: AVAudioPCMBuffer, to segment: OpenSegment, handlers: Handlers) -> Bool {
        guard let file = segment.file else {
            noteWriteError(segment, "the file is not open", handlers: handlers)
            return false
        }
        do {
            if segment.native {
                try file.write(from: buffer)
            } else {
                guard let output = convert(buffer) else { return false }
                if output.frameLength > 0 {
                    try file.write(from: output)
                }
            }
            segment.writeErrors = 0
            return true
        } catch {
            WatchLog.error("Audio write failed: \(error.localizedDescription)")
            if !segment.native, segment.frames == 0, reopenNative(segment, format: buffer.format) {
                // The encoder refused the 16 kHz settings; this segment continues at the native rate.
                return write(buffer, to: segment, handlers: handlers)
            }
            noteWriteError(segment, error.localizedDescription, handlers: handlers)
            return false
        }
    }

    private func noteWriteError(_ segment: OpenSegment, _ detail: String, handlers: Handlers) {
        segment.writeErrors += 1
        if segment.writeErrors >= 5 {
            fail("Couldn't write audio (\(detail)).", handlers: handlers)
        }
    }

    private func reopenNative(_ segment: OpenSegment, format: AVAudioFormat) -> Bool {
        autoreleasepool {
            segment.file = nil
        }
        try? FileManager.default.removeItem(at: segment.url)
        do {
            segment.file = try AVAudioFile(forWriting: segment.url, settings: SegmentWriter.nativeSettings(for: format),
                                           commonFormat: .pcmFormatFloat32, interleaved: false)
            segment.native = true
            preferNative = true
            pipeline = .native
            WatchLog.error("Switched to the native sample rate after an encoder error")
            return true
        } catch {
            WatchLog.error("Native-rate AAC unavailable too: \(error.localizedDescription)")
            return false
        }
    }

    private func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        switch pipeline {
        case .passthrough, .native:
            return buffer
        case .converted(let converter, let target):
            let ratio = target.sampleRate / buffer.format.sampleRate
            let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return nil }
            let feed = InputFeed(buffer)
            var conversionError: NSError?
            let status = converter.convert(to: output, error: &conversionError) { _, inputStatus in
                if let next = feed.take() {
                    inputStatus.pointee = .haveData
                    return next
                }
                inputStatus.pointee = .noDataNow
                return nil
            }
            switch status {
            case .haveData, .inputRanDry, .endOfStream:
                conversionErrors = 0
                return output
            case .error:
                conversionErrors += 1
                WatchLog.error("Audio conversion failed: \(conversionError?.localizedDescription ?? "unknown error")")
                return nil
            @unknown default:
                return output
            }
        }
    }

    private func finishCurrent(reason: SegmentReason) -> FinishedSegment? {
        guard let segment = current else { return nil }
        current = nil
        // Releasing the last reference finalises the MP4 container; the pool makes
        // sure that happens before the file is handed on.
        autoreleasepool {
            if #available(watchOS 11.0, *) {
                segment.file?.close()
            }
            segment.file = nil
        }
        guard segment.frames > 0 else {
            try? FileManager.default.removeItem(at: segment.url)
            return nil
        }
        let duration = Double(segment.frames) / segment.sampleRate
        let average: Float = segment.bufferCount > 0 ? Float(segment.dbSum / Double(segment.bufferCount)) : -160
        let speech: Float = segment.bufferCount > 0 ? Float(segment.speechCount) / Float(segment.bufferCount) : 0
        let meta = SegmentMeta(id: segment.id, device: device, startedAt: segment.startedAt, duration: duration,
                               avgPower: average, peakPower: segment.peak, speechRatio: speech, reason: reason)
        return FinishedSegment(url: segment.url, meta: meta)
    }

    private func fail(_ message: String, handlers: Handlers) {
        guard !reportedFailure else { return }
        reportedFailure = true
        handlers.failed(message)
    }

    // MARK: Helpers

    private static var compactSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
        ]
    }

    private static func nativeSettings(for format: AVAudioFormat) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
        ]
    }

    /// The tap's buffer belongs to the engine; copy it before hopping threads.
    private static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: source.frameLength) else { return nil }
        copy.frameLength = source.frameLength
        let from = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: source.audioBufferList))
        let to = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        guard from.count == to.count else { return nil }
        for index in 0..<from.count {
            guard let sourceData = from[index].mData, let targetData = to[index].mData else { return nil }
            let bytes = min(Int(from[index].mDataByteSize), Int(to[index].mDataByteSize))
            _ = memcpy(targetData, sourceData, bytes)
        }
        return copy
    }

    /// RMS and peak of the first channel, in dBFS (-160…0).
    private static func levels(of buffer: AVAudioPCMBuffer) -> (rms: Float, peak: Float) {
        let count = Int(buffer.frameLength)
        guard count > 0, let channels = buffer.floatChannelData else { return (-160, -160) }
        let samples = channels[0]
        var sumOfSquares: Float = 0
        var peak: Float = 0
        for index in 0..<count {
            let sample = samples[index]
            sumOfSquares += sample * sample
            let magnitude = abs(sample)
            if magnitude > peak { peak = magnitude }
        }
        let rms = (sumOfSquares / Float(count)).squareRoot()
        return (decibels(rms), decibels(peak))
    }

    private static func decibels(_ amplitude: Float) -> Float {
        guard amplitude > 0, amplitude.isFinite else { return -160 }
        return min(0, max(-160, 20 * log10(amplitude)))
    }
}
