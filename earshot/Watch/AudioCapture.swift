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
struct VoiceWindowToken {
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

// MARK: - AudioCapture

@MainActor
final class AudioCapture: ObservableObject {
    @Published private(set) var state: RecorderState = .idle
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

    private var engine = AVAudioEngine()
    private let writer: SegmentWriter
    private var settings: RemoteWatchSettings
    private var recordedDay: String
    private var tapInstalled = false
    private var isStarting = false
    private var isForeground = false
    private var pauseTimer: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []
    private var lastBackgroundPublish = Date.distantPast

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
        let wasPaused = isPrivacyPaused
        guard await beginCapture(temporary: false) else { return }
        setWantsRecording(true)
        if wasPaused { endPrivacyPause() }
        LocalNotifier.cancel([NoticeID.resume, NoticeID.lowBattery])
        UserDefaults.standard.set(false, forKey: Keys.resumeReminderSent)
        notice = nil
        Haptics.start()
        WatchLog.info("Recording started")
    }

    func resume() async {
        await start()
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
        WatchLog.info("Recording stopped by the user")
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
    }

    func setForeground(_ active: Bool) {
        isForeground = active
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
            if let until, until.timeIntervalSinceNow <= 0 { await resume() }
        case .interrupted, .error, .idle:
            await start()
        }
    }

    /// Called every minute: midnight reset, battery, pause expiry.
    func periodicCheck() {
        rollDayIfNeeded()
        checkBattery()
        if isForeground, !isStarting, case .paused(let until?) = state, until.timeIntervalSinceNow <= 0 {
            Task { await self.resume() }
        }
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
            isInVoiceWindow = true
            return VoiceWindowToken(previous: previous, temporary: false)
        }
        guard await beginCapture(temporary: true) else { return nil }
        isInVoiceWindow = true
        WatchLog.info("Microphone started for a voice answer")
        return VoiceWindowToken(previous: previous, temporary: true)
    }

    /// Closes the segment holding the spoken answer (so it uploads right away) and
    /// returns the recorder to the state it was in before the window.
    func endVoiceWindow(_ token: VoiceWindowToken) {
        isInVoiceWindow = false
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
        isInVoiceWindow = false
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

    private func restoredState(_ previous: RecorderState) -> RecorderState {
        switch previous {
        case .recording, .interrupted:
            return wantsRecording ? .interrupted : .idle
        case .idle, .paused, .error:
            return previous
        }
    }

    // MARK: Engine

    private func beginCapture(temporary: Bool) async -> Bool {
        if state == .recording { return true }
        guard !isStarting else { return false }
        isStarting = true
        defer { isStarting = false }

        guard await microphonePermission() else {
            report("Microphone access is off. Allow it in Settings › Privacy & Security › Microphone.")
            return false
        }
        if !temporary, let message = batteryBlockMessage() {
            report(message)
            return false
        }
        do {
            try startEngine()
        } catch {
            WatchLog.error("Couldn't start recording: \(error.localizedDescription)")
            report("Couldn't start the microphone (\(error.localizedDescription)). Open Earshot and try again.")
            return false
        }
        state = .recording
        return true
    }

    private func startEngine() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [])
        try session.setActive(true, options: [])

        removeTap()
        if engine.isRunning { engine.stop() }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError.noMicrophone }

        writer.begin(inputFormat: format)
        writer.installTap(on: input, format: format)
        tapInstalled = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            removeTap()
            finishSegment(reason: .interruption, stopAccepting: true)
            throw error
        }
        WatchLog.info("Engine running at \(Int(format.sampleRate)) Hz, \(format.channelCount) channel(s)")
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
    private func report(_ message: String) {
        notice = message
        switch state {
        case .paused, .interrupted:
            break
        case .idle, .recording, .error:
            state = .error(message)
        }
        Haptics.failure()
    }

    private func becomeInterrupted(_ body: String) {
        state = .interrupted
        level = -160
        segmentElapsed = 0
        UserDefaults.standard.set(true, forKey: Keys.resumeReminderSent)
        LocalNotifier.post(id: NoticeID.resume, title: "Recording paused", body: body,
                           category: LocalNotifier.resumeCategory)
        Haptics.warning()
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
        if segment.meta.reason == .rotation { checkBattery() }
    }

    private func updateMeter(db: Float, elapsed: Double) {
        guard state == .recording else { return }
        if isForeground {
            level = db
            segmentElapsed = elapsed
        } else if Date().timeIntervalSince(lastBackgroundPublish) >= 10 {
            // Keep UI work minimal while the screen is off.
            lastBackgroundPublish = Date()
            segmentElapsed = elapsed
        }
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
        Haptics.warning()
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
        Haptics.warning()
        WatchLog.info("Stopped recording at \(percent)% battery")
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
        await resume()
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
        if item.arrival.timeIntervalSince(lastLevelReport) >= 0.25 {
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
