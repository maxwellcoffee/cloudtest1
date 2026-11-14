//  Transcribers.swift
//  Speech-to-text engines used by the ingest pipeline:
//  - Apple SpeechAnalyzer / SpeechTranscriber (macOS 26+, on-device, model via AssetInventory)
//  - Apple SFSpeechRecognizer (on-device when supported; server requests split into < 1 min chunks)
//  - Any OpenAI-compatible /audio/transcriptions endpoint (Whisper)

import Foundation
import AVFoundation
import CoreMedia
import Speech

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
    static func make(_ settings: AppSettings) -> Transcriber {
        switch settings.transcriptionEngine {
        case .speechAnalyzer:
            if #available(macOS 26.0, *) {
                return EarshotSpeechAnalyzerTranscriber()
            }
            return EarshotAppleSpeechTranscriber()
        case .appleSpeech:
            return EarshotAppleSpeechTranscriber()
        case .whisperAPI:
            return EarshotWhisperTranscriber(baseURL: settings.whisperBaseURL, model: settings.whisperModel)
        }
    }

    /// Asks for speech-recognition permission if needed. True when authorised.
    static func requestSpeechAuthorization() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            break
        @unknown default:
            return false
        }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

// MARK: - Errors

private enum EarshotTranscriptionError: LocalizedError {
    case notAuthorized
    case unsupportedLocale(String)
    case recognizerUnavailable(String)
    case invalidAudio(String)
    case invalidEndpoint(String)
    case http(status: Int, message: String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not allowed. Enable it in System Settings → Privacy & Security → Speech Recognition."
        case .unsupportedLocale(let identifier):
            return "Speech recognition does not support the language \(identifier)."
        case .recognizerUnavailable(let identifier):
            return "The speech recogniser for \(identifier) is currently unavailable (it may need a network connection)."
        case .invalidAudio(let detail):
            return "The audio could not be read: \(detail)"
        case .invalidEndpoint(let url):
            return "The transcription endpoint URL is invalid: \(url)"
        case .http(let status, let message):
            return "Transcription API error \(status): \(message)"
        case .invalidResponse(let detail):
            return "Unexpected transcription API response: \(detail)"
        }
    }
}

// MARK: - Audio helpers

private enum EarshotAudioTools {
    struct Chunk {
        let url: URL
        let offset: TimeInterval
        let duration: TimeInterval
    }

    static func duration(of url: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let sampleRate = file.fileFormat.sampleRate
        guard sampleRate > 0 else { return nil }
        return Double(file.length) / sampleRate
    }

    /// Decodes `url` and writes consecutive 16-bit PCM WAV chunks of at most `maxChunkSeconds`.
    /// The caller deletes the returned files.
    static func split(_ url: URL, maxChunkSeconds: TimeInterval) throws -> [Chunk] {
        let input = try AVAudioFile(forReading: url)
        let format = input.processingFormat
        let sampleRate = format.sampleRate
        guard sampleRate > 0 else {
            throw EarshotTranscriptionError.invalidAudio("unknown sample rate")
        }
        let framesPerChunk = AVAudioFrameCount(max(1, maxChunkSeconds * sampleRate))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerChunk) else {
            throw EarshotTranscriptionError.invalidAudio("could not allocate an audio buffer")
        }
        let fileSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: Int(format.channelCount),
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        var chunks: [Chunk] = []
        var offsetFrames: AVAudioFramePosition = 0
        do {
            while input.framePosition < input.length {
                try input.read(into: buffer, frameCount: framesPerChunk)
                if buffer.frameLength == 0 { break }
                let chunkURL = AppPaths.temporaryDirectory
                    .appendingPathComponent("speech-chunk-\(UUID().uuidString)")
                    .appendingPathExtension("wav")
                try writeChunk(buffer, to: chunkURL, settings: fileSettings, format: format)
                let frames = AVAudioFramePosition(buffer.frameLength)
                chunks.append(Chunk(url: chunkURL,
                                    offset: Double(offsetFrames) / sampleRate,
                                    duration: Double(frames) / sampleRate))
                offsetFrames += frames
            }
        } catch {
            for chunk in chunks { try? FileManager.default.removeItem(at: chunk.url) }
            throw error
        }
        return chunks
    }

    private static func writeChunk(_ buffer: AVAudioPCMBuffer, to url: URL, settings: [String: Any],
                                   format: AVAudioFormat) throws {
        let output = try AVAudioFile(forWriting: url, settings: settings,
                                     commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        try output.write(from: buffer)
        if #available(macOS 15.0, *) {
            output.close()
        }
        // On macOS 14 the file is finalised when `output` is released at the end of this scope.
    }
}

// MARK: - SpeechAnalyzer (macOS 26+)

@available(macOS 26.0, *)
private struct EarshotSpeechAnalyzerTranscriber: Transcriber {
    var name: String { "Apple SpeechAnalyzer" }

    func transcribe(fileURL: URL, locale: Locale) async throws -> [TranscriptPiece] {
        guard SpeechTranscriber.isAvailable else {
            Log.info("SpeechTranscriber is not available on this Mac; using SFSpeechRecognizer")
            return try await EarshotAppleSpeechTranscriber().transcribe(fileURL: fileURL, locale: locale)
        }
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            Log.info("SpeechTranscriber does not support \(locale.identifier); using SFSpeechRecognizer")
            return try await EarshotAppleSpeechTranscriber().transcribe(fileURL: fileURL, locale: locale)
        }

        let transcriber = SpeechTranscriber(locale: supportedLocale,
                                            transcriptionOptions: [],
                                            reportingOptions: [],
                                            attributeOptions: [.audioTimeRange])
        if let installation = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            Log.info("Downloading the on-device speech model for \(supportedLocale.identifier)…")
            try await installation.downloadAndInstall()
            Log.info("Speech model for \(supportedLocale.identifier) installed")
        }

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: fileURL)
        } catch {
            throw EarshotTranscriptionError.invalidAudio(error.localizedDescription)
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber], options: nil)

        // Start collecting before feeding audio so no result is missed.
        let collector = Task { () async throws -> [TranscriptPiece] in
            var pieces: [TranscriptPiece] = []
            for try await result in transcriber.results {
                guard result.isFinal else { continue }
                let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let start = result.range.start.seconds
                let end = result.range.end.seconds
                let safeStart = start.isFinite ? max(0, start) : 0
                let safeEnd = end.isFinite ? max(safeStart, end) : safeStart
                pieces.append(TranscriptPiece(start: safeStart, end: safeEnd, text: text))
            }
            return pieces
        }

        do {
            if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }
        } catch {
            collector.cancel()
            await analyzer.cancelAndFinishNow()
            throw error
        }

        return try await withTaskCancellationHandler {
            try await collector.value
        } onCancel: {
            collector.cancel()
        }
    }
}

// MARK: - SFSpeechRecognizer

/// One recognition request: resumes its continuation exactly once and forwards cancellation.
private final class EarshotRecognitionState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[TranscriptPiece], Error>?
    private var task: SFSpeechRecognitionTask?
    private var cancelled = false
    private var finished = false

    /// Returns false (and fails the continuation) if the request was already cancelled.
    func install(_ continuation: CheckedContinuation<[TranscriptPiece], Error>) -> Bool {
        lock.lock()
        if cancelled {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func attach(_ recognitionTask: SFSpeechRecognitionTask) {
        lock.lock()
        let cancelNow = cancelled
        if !cancelNow && !finished { task = recognitionTask }
        lock.unlock()
        if cancelNow { recognitionTask.cancel() }
    }

    func finish(_ result: Result<[TranscriptPiece], Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        finished = true
        task = nil
        lock.unlock()
        pending?.resume(with: result)
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let pending = continuation
        continuation = nil
        let running = task
        task = nil
        lock.unlock()
        running?.cancel()
        pending?.resume(throwing: CancellationError())
    }
}

private struct EarshotAppleSpeechTranscriber: Transcriber {
    /// Server-based recognition is limited to about one minute of audio per request.
    private static let serverLimitSeconds: TimeInterval = 55
    private static let serverChunkSeconds: TimeInterval = 50
    private static let trailingPunctuation: Set<Character> = [".", ",", "!", "?", ";", ":", "…"]

    var name: String { "Apple Speech" }

    func transcribe(fileURL: URL, locale: Locale) async throws -> [TranscriptPiece] {
        guard await TranscriberFactory.requestSpeechAuthorization() else {
            throw EarshotTranscriptionError.notAuthorized
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw EarshotTranscriptionError.unsupportedLocale(locale.identifier)
        }
        // Deliver results off the main thread.
        let callbackQueue = OperationQueue()
        callbackQueue.name = "com.example.earshot.speech-results"
        callbackQueue.maxConcurrentOperationCount = 1
        recognizer.queue = callbackQueue

        let onDevice = recognizer.supportsOnDeviceRecognition
        guard onDevice || recognizer.isAvailable else {
            throw EarshotTranscriptionError.recognizerUnavailable(locale.identifier)
        }
        guard let duration = EarshotAudioTools.duration(of: fileURL) else {
            throw EarshotTranscriptionError.invalidAudio(fileURL.lastPathComponent)
        }

        if onDevice || duration <= EarshotAppleSpeechTranscriber.serverLimitSeconds {
            return try await recognize(url: fileURL, duration: duration, offset: 0,
                                       recognizer: recognizer, onDevice: onDevice)
        }

        let chunks = try EarshotAudioTools.split(fileURL, maxChunkSeconds: EarshotAppleSpeechTranscriber.serverChunkSeconds)
        defer {
            for chunk in chunks { try? FileManager.default.removeItem(at: chunk.url) }
        }
        var pieces: [TranscriptPiece] = []
        for chunk in chunks {
            try Task.checkCancellation()
            let chunkPieces = try await recognize(url: chunk.url, duration: chunk.duration, offset: chunk.offset,
                                                  recognizer: recognizer, onDevice: false)
            pieces.append(contentsOf: chunkPieces)
        }
        return pieces
    }

    private func recognize(url: URL, duration: TimeInterval, offset: TimeInterval,
                           recognizer: SFSpeechRecognizer, onDevice: Bool) async throws -> [TranscriptPiece] {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = onDevice
        request.taskHint = .dictation

        let state = EarshotRecognitionState()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[TranscriptPiece], Error>) in
                guard state.install(continuation) else { return }
                let recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                    if let result, result.isFinal {
                        let pieces = EarshotAppleSpeechTranscriber.pieces(from: result, offset: offset, duration: duration)
                        state.finish(.success(pieces))
                    } else if let error {
                        if EarshotAppleSpeechTranscriber.isNoSpeech(error) {
                            state.finish(.success([]))
                        } else {
                            state.finish(.failure(error))
                        }
                    }
                }
                state.attach(recognitionTask)
            }
        } onCancel: {
            state.cancel()
        }
    }

    /// Maps word segments to pieces, re-attaching punctuation from the formatted string.
    private static func pieces(from result: SFSpeechRecognitionResult, offset: TimeInterval,
                               duration: TimeInterval) -> [TranscriptPiece] {
        let transcription = result.bestTranscription
        let formatted = transcription.formattedString
        var pieces: [TranscriptPiece] = []
        var cursor = formatted.startIndex
        for segment in transcription.segments {
            var text = segment.substring.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if cursor < formatted.endIndex,
               let found = formatted.range(of: text, options: [.caseInsensitive], range: cursor..<formatted.endIndex) {
                var end = found.upperBound
                while end < formatted.endIndex, trailingPunctuation.contains(formatted[end]) {
                    end = formatted.index(after: end)
                }
                text = String(formatted[found.lowerBound..<end])
                cursor = end
            }
            let start = offset + max(0, segment.timestamp)
            pieces.append(TranscriptPiece(start: start, end: start + max(0, segment.duration), text: text))
        }

        if pieces.isEmpty {
            let text = formatted.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                pieces = [TranscriptPiece(start: offset, end: offset + max(0, duration), text: text)]
            }
            return pieces
        }

        // Some results carry no timing; spread the words evenly over the audio instead.
        let untimed = pieces.allSatisfy { $0.start == offset && $0.end == offset }
        if untimed && pieces.count > 1 && duration > 0 {
            let step = duration / Double(pieces.count)
            pieces = pieces.enumerated().map { item in
                TranscriptPiece(start: offset + step * Double(item.offset),
                                end: offset + step * Double(item.offset + 1),
                                text: item.element.text)
            }
        }
        return pieces
    }

    /// "No speech detected" is an empty transcript, not a failure.
    private static func isNoSpeech(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 { return true }
        return nsError.localizedDescription.lowercased().contains("no speech detected")
    }
}

// MARK: - Whisper-compatible HTTP API

private struct EarshotWhisperResponse: Decodable {
    struct Piece: Decodable {
        let start: Double?
        let end: Double?
        let text: String?
    }

    let text: String?
    let segments: [Piece]?
}

private struct EarshotWhisperTranscriber: Transcriber {
    let baseURL: String
    let model: String

    var name: String { "Whisper API (\(model))" }

    func transcribe(fileURL: URL, locale: Locale) async throws -> [TranscriptPiece] {
        let audio: Data
        do {
            audio = try Data(contentsOf: fileURL)
        } catch {
            throw EarshotTranscriptionError.invalidAudio(error.localizedDescription)
        }
        guard !audio.isEmpty else { return [] }
        let duration = EarshotAudioTools.duration(of: fileURL) ?? 0
        do {
            return try await send(audio: audio, fileName: fileURL.lastPathComponent, locale: locale,
                                  verbose: true, duration: duration)
        } catch EarshotTranscriptionError.http(let status, let message)
                    where status == 400 && EarshotWhisperTranscriber.rejectsVerboseFormat(message) {
            Log.info("The transcription endpoint rejected verbose_json (\(message)); retrying with plain JSON")
            return try await send(audio: audio, fileName: fileURL.lastPathComponent, locale: locale,
                                  verbose: false, duration: duration)
        }
    }

    private func send(audio: Data, fileName: String, locale: Locale, verbose: Bool,
                      duration: TimeInterval) async throws -> [TranscriptPiece] {
        var base = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/audio/transcriptions"), url.scheme != nil else {
            throw EarshotTranscriptionError.invalidEndpoint(baseURL)
        }

        let boundary = "EarshotBoundary-\(UUID().uuidString)"
        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8))
            body.append(Data("\(value)\r\n".utf8))
        }
        appendField("model", model.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "whisper-1")
        appendField("response_format", verbose ? "verbose_json" : "json")
        if verbose { appendField("timestamp_granularities[]", "segment") }
        if let language = locale.language.languageCode?.identifier, !language.isEmpty {
            appendField("language", language)
        }
        let safeName = fileName.replacingOccurrences(of: "\"", with: "")
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(EarshotWhisperTranscriber.mimeType(for: fileName))\r\n\r\n".utf8))
        body.append(audio)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let key = SettingsStore.whisperKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = response as? HTTPURLResponse else {
            throw EarshotTranscriptionError.invalidResponse("no HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw EarshotTranscriptionError.http(status: http.statusCode,
                                                 message: EarshotWhisperTranscriber.errorMessage(from: data))
        }

        let decoded: EarshotWhisperResponse
        do {
            decoded = try JSONDecoder().decode(EarshotWhisperResponse.self, from: data)
        } catch {
            let preview = String(decoding: data.prefix(200), as: UTF8.self)
            throw EarshotTranscriptionError.invalidResponse("could not decode JSON (\(preview))")
        }

        var pieces: [TranscriptPiece] = []
        for item in decoded.segments ?? [] {
            let text = (item.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let start = max(0, item.start ?? 0)
            let end = max(start, item.end ?? start)
            pieces.append(TranscriptPiece(start: start, end: end, text: text))
        }
        if pieces.isEmpty, let text = decoded.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            // No timestamps: one piece over the whole file (the assembler splits long text).
            pieces = [TranscriptPiece(start: 0, end: max(0, duration), text: text)]
        }
        return pieces
    }

    private static func rejectsVerboseFormat(_ message: String) -> Bool {
        let lower = message.lowercased()
        return lower.contains("response_format") || lower.contains("verbose_json") || lower.contains("timestamp_granularities")
    }

    private static func errorMessage(from data: Data) -> String {
        if let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            if let error = object["error"] as? [String: Any], let message = error["message"] as? String {
                return message
            }
            if let message = object["error"] as? String { return message }
            if let message = object["message"] as? String { return message }
            if let detail = object["detail"] as? String { return detail }
        }
        let text = String(decoding: data.prefix(300), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "no details" : text
    }

    private static func mimeType(for fileName: String) -> String {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "m4a", "mp4", "aac": return "audio/mp4"
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        case "caf": return "audio/x-caf"
        case "aiff", "aif": return "audio/aiff"
        case "flac": return "audio/flac"
        case "ogg", "oga": return "audio/ogg"
        case "webm": return "audio/webm"
        default: return "application/octet-stream"
        }
    }
}
