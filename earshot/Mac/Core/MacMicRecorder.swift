//  MacMicRecorder.swift
//  "Desk mode": records the Mac's microphone in fixed-length AAC segments and
//  hands each finished segment to the ingest pipeline, exactly like a watch upload.
//  (AVAudioSession does not exist on macOS; AVAudioRecorder uses the default input.)

import Foundation
import AVFoundation
import Combine

@MainActor
final class MacMicRecorder: ObservableObject {
    @Published private(set) var isRecording: Bool = false
    /// dBFS of the current segment's latest meter reading (-160 when idle).
    @Published private(set) var level: Float = -160
    @Published private(set) var lastError: String?

    private static let deviceName = "mac-mic"
    private static let meterInterval: TimeInterval = 0.5
    /// Segments shorter than this (e.g. stop right after start) are discarded.
    private static let minimumSegmentSeconds: TimeInterval = 1
    /// A recorder that dies sooner than this after starting is treated as a broken input device.
    private static let minimumHealthySegmentSeconds: TimeInterval = 3

    private let pipeline: IngestPipeline
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var isStarting = false

    // Current segment.
    private var segmentID = UUID().uuidString
    private var segmentURL: URL?
    private var segmentStart = Date()
    private var meterSamples = 0
    private var speechSamples = 0
    private var linearPowerSum: Double = 0
    private var peakPower: Float = -160

    init(pipeline: IngestPipeline) {
        self.pipeline = pipeline
    }

    /// Asks for microphone permission, then records segments of settings.segmentSeconds until stop().
    func start() async {
        guard !isRecording, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        guard await ensureMicrophonePermission() else { return }
        do {
            try beginSegment()
        } catch {
            lastError = "Could not start the microphone: \(error.localizedDescription)"
            Log.error("Mac mic: \(lastError ?? "")")
            return
        }
        isRecording = true
        lastError = nil
        startMeterTimer()
        Log.info("Mac mic: recording started")
    }

    func stop() {
        guard isRecording || recorder != nil else { return }
        stopMeterTimer()
        finishSegment(reason: .stopped, startNext: false)
        isRecording = false
        level = -160
        Log.info("Mac mic: recording stopped")
    }

    // MARK: - Permission

    private func ensureMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            if !granted {
                lastError = "Microphone access was denied. Allow Earshot in System Settings → Privacy & Security → Microphone."
            }
            return granted
        case .denied, .restricted:
            lastError = "Microphone access is off. Allow Earshot in System Settings → Privacy & Security → Microphone."
            return false
        @unknown default:
            lastError = "Microphone access is unavailable."
            return false
        }
    }

    // MARK: - Segments

    private func beginSegment() throws {
        let id = UUID().uuidString
        let url = AppPaths.temporaryDirectory.appendingPathComponent("mac-mic-\(id)").appendingPathExtension("m4a")
        var settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        let newRecorder: AVAudioRecorder
        if let configured = try? MacMicRecorder.makeRecorder(url: url, settings: settings) {
            newRecorder = configured
        } else {
            // Some input devices reject the fixed bit rate; let the encoder choose.
            try? FileManager.default.removeItem(at: url)
            settings.removeValue(forKey: AVEncoderBitRateKey)
            newRecorder = try MacMicRecorder.makeRecorder(url: url, settings: settings)
        }
        recorder = newRecorder
        segmentID = id
        segmentURL = url
        segmentStart = Date()
        meterSamples = 0
        speechSamples = 0
        linearPowerSum = 0
        peakPower = -160
    }

    private static func makeRecorder(url: URL, settings: [String: Any]) throws -> AVAudioRecorder {
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.prepareToRecord(), recorder.record() else {
            throw MacMicRecorderError(message: "The audio recorder refused to start (is an input device connected?).")
        }
        return recorder
    }

    /// Closes the current file, optionally starts the next one immediately, then ingests the closed file.
    private func finishSegment(reason: SegmentReason, startNext: Bool) {
        guard let current = recorder, let url = segmentURL else { return }
        let wallClock = Date().timeIntervalSince(segmentStart)
        let recorded = current.isRecording ? current.currentTime : 0
        let duration = recorded > 0 ? recorded : wallClock
        current.stop()
        recorder = nil
        segmentURL = nil

        let id = segmentID
        let startedAt = segmentStart
        let samples = meterSamples
        let averagePower: Float = samples > 0
            ? Float(10 * log10(max(linearPowerSum / Double(samples), 1e-16)))
            : -160
        let peak = peakPower
        let speechRatio: Float = samples > 0 ? Float(speechSamples) / Float(samples) : 0
        let reasonRaw = reason.rawValue

        if startNext {
            do {
                try beginSegment()
            } catch {
                lastError = "The microphone stopped: \(error.localizedDescription)"
                Log.error("Mac mic: could not start the next segment: \(error.localizedDescription)")
                stopMeterTimer()
                isRecording = false
                level = -160
            }
        }

        guard duration >= MacMicRecorder.minimumSegmentSeconds else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let pipeline = self.pipeline
        let device = MacMicRecorder.deviceName
        Task.detached(priority: .utility) {
            let meta = SegmentMeta(id: id, device: device, startedAt: startedAt, duration: duration,
                                   avgPower: averagePower, peakPower: peak, speechRatio: speechRatio,
                                   reason: SegmentReason(rawValue: reasonRaw) ?? .rotation)
            let ack = pipeline.ingestFile(at: url, meta: meta, move: true)
            if !ack.accepted {
                Log.error("Mac mic: segment \(id) was not stored: \(ack.message ?? "unknown error")")
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Metering

    private func startMeterTimer() {
        stopMeterTimer()
        let timer = Timer(timeInterval: MacMicRecorder.meterInterval, repeats: true) { [weak self] _ in
            guard let owner = self else { return }
            Task { @MainActor in
                owner.meterTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func meterTick() {
        guard isRecording, let current = recorder else { return }
        if !current.isRecording {
            // The input device went away or the encoder failed.
            if Date().timeIntervalSince(segmentStart) < MacMicRecorder.minimumHealthySegmentSeconds {
                // It failed right after (re)starting: give up instead of restarting in a loop.
                Log.error("Mac mic: the recorder keeps stopping; turning the Mac microphone off")
                stop()
                lastError = "The microphone stopped recording. Check the input device in System Settings → Sound."
            } else {
                Log.error("Mac mic: the recorder stopped unexpectedly; starting a new segment")
                finishSegment(reason: .interruption, startNext: true)
            }
            return
        }
        current.updateMeters()
        let average = current.averagePower(forChannel: 0)
        let peak = current.peakPower(forChannel: 0)
        level = average
        meterSamples += 1
        linearPowerSum += pow(10, Double(average) / 10)
        peakPower = max(peakPower, peak)

        let settings = SettingsStore.current
        if average > settings.silenceThresholdDB {
            speechSamples += 1
        }
        let segmentLength = TimeInterval(max(settings.segmentSeconds, 10))
        if Date().timeIntervalSince(segmentStart) >= segmentLength {
            finishSegment(reason: .rotation, startNext: true)
        }
    }
}

private struct MacMicRecorderError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
