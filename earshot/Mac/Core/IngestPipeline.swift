//  IngestPipeline.swift
//  Stores incoming audio segments and transcribes them one at a time.
//
//  ingest/ingestFile → audio saved under AppPaths.audioDirectory(for:) → Segment
//  (.received) → FIFO queue → single worker: .transcribing → Transcriber →
//  UtteranceAssembler → db.insertUtterances → .transcribed (or .failed) →
//  onTranscribed → EarshotEvents (.segments, .utterances).

import Foundation
import AVFoundation

// MARK: - Pipeline

final class IngestPipeline: @unchecked Sendable {
    /// Segments whose speech ratio is below this are not transcribed (when skipSilentSegments).
    private static let silentSpeechRatio: Float = 0.02
    /// kv key holding the ids of failed segments that were already retried once.
    private static let retriedFailedKey = "ingest.retriedFailed"

    private let db: Database

    /// Guards the queue state below.
    private let lock = NSLock()
    private var pendingIDs: [String] = []
    private var pendingSet = Set<String>()
    private var currentID: String?
    private var workerRunning = false
    private var transcribedHandler: (@Sendable (_ segment: Segment, _ utterances: [Utterance]) -> Void)?

    /// Serialises "already stored?" checks with file writes so concurrent uploads of one id are safe.
    private let ingestLock = NSLock()

    init(db: Database) {
        self.db = db
    }

    /// Called after a segment is transcribed (any thread).
    var onTranscribed: (@Sendable (_ segment: Segment, _ utterances: [Utterance]) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return transcribedHandler
        }
        set {
            lock.lock()
            transcribedHandler = newValue
            lock.unlock()
        }
    }

    // MARK: Ingest

    /// Saves audio under AppPaths.audioDirectory(for:), stores the segment (.received), schedules
    /// transcription. Idempotent per meta.id.
    func ingest(audio: Data, meta: SegmentMeta) -> SegmentAck {
        guard !audio.isEmpty else {
            return SegmentAck(id: meta.id, accepted: false, message: "The audio body is empty.")
        }
        ingestLock.lock()
        defer { ingestLock.unlock() }

        if db.segment(id: meta.id) != nil {
            return SegmentAck(id: meta.id, accepted: true, message: "Already received.")
        }
        let destination = IngestPipeline.destinationURL(for: meta, fileExtension: "m4a")
        do {
            try audio.write(to: destination, options: .atomic)
        } catch {
            Log.error("Ingest: could not write audio for segment \(meta.id): \(error.localizedDescription)")
            return SegmentAck(id: meta.id, accepted: false,
                              message: "Could not store the audio: \(error.localizedDescription)")
        }
        return register(meta: meta, fileURL: destination)
    }

    /// Imports a local audio file (Mac mic, drag & drop). move=true moves instead of copying.
    func ingestFile(at url: URL, meta: SegmentMeta, move: Bool) -> SegmentAck {
        ingestLock.lock()
        defer { ingestLock.unlock() }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            return SegmentAck(id: meta.id, accepted: false, message: "The file \(url.lastPathComponent) does not exist.")
        }
        if db.segment(id: meta.id) != nil {
            if move { try? fileManager.removeItem(at: url) }
            return SegmentAck(id: meta.id, accepted: true, message: "Already received.")
        }
        let fileExtension = url.pathExtension.isEmpty ? "m4a" : url.pathExtension.lowercased()
        let destination = IngestPipeline.destinationURL(for: meta, fileExtension: fileExtension)
        do {
            if move {
                try fileManager.moveItem(at: url, to: destination)
            } else {
                try fileManager.copyItem(at: url, to: destination)
            }
        } catch {
            Log.error("Ingest: could not \(move ? "move" : "copy") \(url.lastPathComponent): \(error.localizedDescription)")
            return SegmentAck(id: meta.id, accepted: false,
                              message: "Could not import the audio: \(error.localizedDescription)")
        }
        return register(meta: meta, fileURL: destination)
    }

    // MARK: Queue control

    /// Re-queues .received/.transcribing segments at launch and retries each failed segment once.
    func resumePending() {
        var toQueue: [String] = []

        let interrupted = db.segments(statuses: [.received, .transcribing], limit: 100_000)
        for var segment in interrupted {
            if segment.status == .transcribing {
                segment.status = .received
                db.upsertSegment(segment)
            }
            toQueue.append(segment.id)
        }

        let failed = db.segments(statuses: [.failed], limit: 2_000)
        var retried = loadRetriedIDs()
        var retryCount = 0
        for segment in failed where !retried.contains(segment.id) {
            guard let path = segment.filePath, FileManager.default.fileExists(atPath: path) else { continue }
            retried.insert(segment.id)
            toQueue.append(segment.id)
            retryCount += 1
        }
        // Forget ids that are no longer failed (they succeeded or were deleted).
        let failedIDs = Set(failed.map { $0.id })
        saveRetriedIDs(retried.intersection(failedIDs))

        if !toQueue.isEmpty {
            Log.info("Ingest: resuming \(interrupted.count) pending segment(s), retrying \(retryCount) failed")
            if !interrupted.isEmpty { EarshotEvents.post(.segments) }
            enqueue(toQueue)
        }
    }

    /// Deletes audio older than keepAudioDays (0 = everything already transcribed).
    @discardableResult
    func applyRetention() -> Int {
        let days = SettingsStore.current.keepAudioDays
        let now = Date()
        let cutoff = days <= 0 ? now : now.addingTimeInterval(-Double(days) * 86_400)
        // With "delete right away", failed audio is still kept for a day so the retry can run.
        let failedCutoff = days <= 0 ? now.addingTimeInterval(-86_400) : cutoff

        lock.lock()
        var busy = pendingSet
        if let currentID { busy.insert(currentID) }
        lock.unlock()

        let fileManager = FileManager.default
        var removed = 0
        var directories = Set<URL>()
        for var segment in db.segmentsWithAudio(olderThan: cutoff) {
            guard let path = segment.filePath, !busy.contains(segment.id) else { continue }
            switch segment.status {
            case .received, .transcribing:
                continue
            case .failed:
                if segment.startedAt >= failedCutoff { continue }
            case .transcribed, .silent:
                break
            }
            let url = URL(fileURLWithPath: path)
            if fileManager.fileExists(atPath: path) {
                do {
                    try fileManager.removeItem(at: url)
                } catch {
                    Log.error("Retention: could not delete \(url.lastPathComponent): \(error.localizedDescription)")
                    continue
                }
            }
            segment.filePath = nil
            db.upsertSegment(segment)
            directories.insert(url.deletingLastPathComponent())
            removed += 1
        }

        if !directories.isEmpty {
            // Hold the ingest lock so a concurrent upload cannot lose the directory it just created.
            ingestLock.lock()
            for directory in directories {
                let entries = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? ["?"]
                if entries.allSatisfy({ $0.hasPrefix(".") }) {
                    try? fileManager.removeItem(at: directory)
                }
            }
            ingestLock.unlock()
        }

        if removed > 0 {
            Log.info("Retention: deleted audio of \(removed) segment(s)")
            EarshotEvents.post(.segments)
        }
        return removed
    }

    var queueLength: Int {
        lock.lock()
        defer { lock.unlock() }
        return pendingIDs.count + (currentID == nil ? 0 : 1)
    }

    var statusText: String {
        lock.lock()
        let queued = pendingIDs.count
        let busy = currentID != nil
        lock.unlock()
        if busy {
            return queued > 0 ? "Transcribing (\(queued) queued)…" : "Transcribing…"
        }
        return queued > 0 ? "Waiting to transcribe (\(queued) queued)…" : "Idle"
    }

    // MARK: - Private: registration

    /// Stores the segment row for an audio file that is already in place. Call with `ingestLock` held.
    private func register(meta: SegmentMeta, fileURL: URL) -> SegmentAck {
        let settings = SettingsStore.current
        var duration = meta.duration
        if duration <= 0 || !duration.isFinite {
            duration = IngestPipeline.audioDuration(of: fileURL) ?? 0
        }
        let silent = settings.skipSilentSegments && meta.speechRatio < IngestPipeline.silentSpeechRatio
        var segment = Segment(id: meta.id,
                              device: meta.device,
                              startedAt: meta.startedAt,
                              duration: duration,
                              filePath: fileURL.path,
                              status: silent ? .silent : .received,
                              avgPower: meta.avgPower,
                              speechRatio: meta.speechRatio,
                              reason: meta.reason.rawValue,
                              error: nil,
                              createdAt: Date())
        if silent && settings.keepAudioDays == 0 {
            try? FileManager.default.removeItem(at: fileURL)
            segment.filePath = nil
        }
        db.upsertSegment(segment)

        // Only acknowledge what was really persisted: the watch deletes its copy on success.
        guard db.segment(id: meta.id) != nil else {
            try? FileManager.default.removeItem(at: fileURL)
            Log.error("Ingest: the database did not store segment \(meta.id)")
            return SegmentAck(id: meta.id, accepted: false, message: "The Mac could not save the segment.")
        }
        EarshotEvents.post(.segments)

        if silent {
            Log.debug("Ingest: segment \(meta.id) is silent (speech \(meta.speechRatio)); not transcribing")
            return SegmentAck(id: meta.id, accepted: true, message: "Stored (silent, not transcribed).")
        }
        enqueue([meta.id])
        return SegmentAck(id: meta.id, accepted: true, message: "Queued for transcription.")
    }

    private static func destinationURL(for meta: SegmentMeta, fileExtension: String) -> URL {
        let directory = AppPaths.audioDirectory(for: meta.startedAt)
        let baseName = safeFileName(meta.id)
        var url = directory.appendingPathComponent(baseName).appendingPathExtension(fileExtension)
        if FileManager.default.fileExists(atPath: url.path) {
            // A different id sanitised to the same name; never overwrite someone else's audio.
            let suffix = UUID().uuidString.prefix(8)
            url = directory.appendingPathComponent("\(baseName)-\(suffix)").appendingPathExtension(fileExtension)
        }
        return url
    }

    /// Keeps ids usable as file names (no path separators or dot-dot tricks).
    private static func safeFileName(_ id: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var name = ""
        for scalar in id.unicodeScalars where allowed.contains(scalar) {
            name.unicodeScalars.append(scalar)
        }
        if name.count > 120 { name = String(name.prefix(120)) }
        return name.isEmpty ? UUID().uuidString : name
    }

    private static func audioDuration(of url: URL) -> Double? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let sampleRate = file.fileFormat.sampleRate
        guard sampleRate > 0 else { return nil }
        return Double(file.length) / sampleRate
    }

    // MARK: - Private: queue

    private func enqueue(_ ids: [String]) {
        lock.lock()
        for id in ids where id != currentID && !pendingSet.contains(id) {
            pendingIDs.append(id)
            pendingSet.insert(id)
        }
        let startWorker = !workerRunning && !pendingIDs.isEmpty
        if startWorker { workerRunning = true }
        lock.unlock()

        if startWorker {
            Task.detached(priority: .utility) { [weak self] in
                await self?.drainQueue()
            }
        }
        EarshotEvents.post(.status)
    }

    /// Pops the next id, or marks the worker as stopped when the queue is empty.
    private func nextID() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard !pendingIDs.isEmpty else {
            currentID = nil
            workerRunning = false
            return nil
        }
        let id = pendingIDs.removeFirst()
        pendingSet.remove(id)
        currentID = id
        return id
    }

    private func drainQueue() async {
        while let id = nextID() {
            await process(id)
            EarshotEvents.post(.status)
        }
        EarshotEvents.post(.status)
    }

    // MARK: - Private: transcription

    private func process(_ id: String) async {
        guard var segment = db.segment(id: id) else {
            Log.error("Ingest: segment \(id) disappeared before transcription")
            return
        }
        switch segment.status {
        case .received, .transcribing, .failed:
            break
        case .transcribed, .silent:
            return
        }

        let settings = SettingsStore.current
        if settings.skipSilentSegments && segment.speechRatio < IngestPipeline.silentSpeechRatio {
            segment.status = .silent
            segment.error = nil
            db.upsertSegment(segment)
            EarshotEvents.post(.segments)
            return
        }

        // A previous run may have stored the transcript and then been interrupted.
        let existing = db.utterances(segmentID: id)
        if !existing.isEmpty {
            Log.info("Ingest: segment \(id) already has \(existing.count) utterance(s); marking transcribed")
            finishTranscribed(segment, utterances: existing, settings: settings)
            return
        }

        guard let path = segment.filePath, FileManager.default.fileExists(atPath: path) else {
            segment.status = .failed
            segment.error = "The audio file is missing."
            db.upsertSegment(segment)
            EarshotEvents.post(.segments)
            Log.error("Ingest: audio for segment \(id) is missing; cannot transcribe")
            return
        }

        segment.status = .transcribing
        segment.error = nil
        db.upsertSegment(segment)
        EarshotEvents.post(.segments)

        let transcriber = TranscriberFactory.make(settings)
        let fileURL = URL(fileURLWithPath: path)
        let locale = settings.locale
        // Generous: first use of SpeechAnalyzer may download a model.
        let timeout = max(600, segment.duration * 5)
        let started = Date()
        do {
            let pieces = try await IngestPipeline.transcribe(with: transcriber, fileURL: fileURL,
                                                            locale: locale, timeout: timeout)
            let assembled = UtteranceAssembler.assemble(pieces: pieces, segmentID: segment.id,
                                                        segmentStart: segment.startedAt)
            var stored: [Utterance] = []
            if !assembled.isEmpty {
                stored = db.insertUtterances(assembled)
                if stored.isEmpty {
                    throw IngestError(message: "The transcript could not be saved to the database.")
                }
            }
            let seconds = Date().timeIntervalSince(started)
            Log.info("Ingest: transcribed segment \(id) with \(transcriber.name) in \(String(format: "%.1f", seconds)) s → \(stored.count) utterance(s)")
            finishTranscribed(segment, utterances: stored, settings: settings)
        } catch {
            segment.status = .failed
            segment.error = error.localizedDescription
            db.upsertSegment(segment)
            EarshotEvents.post(.segments)
            Log.error("Ingest: transcription of segment \(id) failed (\(transcriber.name)): \(error.localizedDescription)")
        }
    }

    private func finishTranscribed(_ original: Segment, utterances: [Utterance], settings: AppSettings) {
        var segment = original
        segment.status = .transcribed
        segment.error = nil
        if settings.keepAudioDays == 0, let path = segment.filePath {
            try? FileManager.default.removeItem(atPath: path)
            if !FileManager.default.fileExists(atPath: path) {
                segment.filePath = nil
            } else {
                Log.error("Ingest: could not delete audio of segment \(segment.id) after transcription")
            }
        }
        db.upsertSegment(segment)
        onTranscribed?(segment, utterances)
        EarshotEvents.post(.segments)
        EarshotEvents.post(.utterances)
    }

    /// Runs the transcriber in its own task so a hung recogniser cannot stall the queue forever.
    private static func transcribe(with transcriber: Transcriber, fileURL: URL, locale: Locale,
                                   timeout: TimeInterval) async throws -> [TranscriptPiece] {
        let gate = TranscriptionGate()
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[TranscriptPiece], Error>) in
            gate.install(continuation)
            let work = Task {
                do {
                    let pieces = try await transcriber.transcribe(fileURL: fileURL, locale: locale)
                    gate.finish(.success(pieces))
                } catch {
                    gate.finish(.failure(error))
                }
            }
            Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if gate.finish(.failure(IngestError(message: "Transcription timed out after \(Int(timeout)) s."))) {
                    work.cancel()
                }
            }
        }
    }

    // MARK: - Private: retry bookkeeping

    private func loadRetriedIDs() -> Set<String> {
        guard let raw = db.kvGet(IngestPipeline.retriedFailedKey),
              let ids = try? JSONDecoder().decode([String].self, from: Data(raw.utf8)) else { return [] }
        return Set(ids)
    }

    private func saveRetriedIDs(_ ids: Set<String>) {
        guard !ids.isEmpty else {
            db.kvSet(IngestPipeline.retriedFailedKey, nil)
            return
        }
        guard let data = try? JSONEncoder().encode(ids.sorted()) else { return }
        db.kvSet(IngestPipeline.retriedFailedKey, String(decoding: data, as: UTF8.self))
    }
}

private struct IngestError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// One-shot bridge between the transcription task, its deadline and the waiting worker.
private final class TranscriptionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<[TranscriptPiece], Error>?

    func install(_ continuation: CheckedContinuation<[TranscriptPiece], Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    /// Returns true if this call delivered the result.
    @discardableResult
    func finish(_ result: Result<[TranscriptPiece], Error>) -> Bool {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        guard let pending else { return false }
        pending.resume(with: result)
        return true
    }
}

// MARK: - Utterance assembly

/// Pure helper (unit-tested): merges recogniser pieces into sentence-like utterances.
enum UtteranceAssembler {
    /// Pieces closer than this are merged into one utterance.
    private static let maxMergeGap: TimeInterval = 1.2
    /// After sentence-ending punctuation, a pause longer than this starts a new utterance.
    private static let sentenceBreakGap: TimeInterval = 0.6
    private static let maxDuration: TimeInterval = 25
    private static let maxCharacters = 400

    private static let sentenceTerminators: Set<Character> = [".", "!", "?", "…", "。", "！", "？"]
    private static let unspacedTerminators: Set<Character> = ["。", "！", "？"]
    /// Characters that attach to the previous word without a space.
    private static let attachingPunctuation: Set<Character> = [
        ",", ".", "!", "?", ";", ":", "…", ")", "]", "}", "”", "’", "%",
        "。", "，", "！", "？", "、", "：", "；",
    ]
    private static let openingPunctuation: Set<Character> = ["(", "[", "{", "“", "‘"]
    private static let closingQuotes: Set<Character> = ["\"", "'", "”", "’", ")", "]"]

    private struct Draft {
        var start: TimeInterval
        var end: TimeInterval
        var text: String
    }

    static func assemble(pieces: [TranscriptPiece], segmentID: String, segmentStart: Date) -> [Utterance] {
        var drafts: [Draft] = []
        var current: Draft?
        for piece in prepare(pieces) {
            guard let open = current else {
                current = Draft(start: piece.start, end: piece.end, text: piece.text)
                continue
            }
            let gap = piece.start - open.end
            let mergedText = join(open.text, piece.text)
            let mergedEnd = max(open.end, piece.end)
            // After ". ! ?" a new utterance starts on a noticeable pause, or right away when the
            // next piece visibly starts a new sentence (capital letter).
            let startsNewSentence = piece.text.first?.isUppercase ?? false
            let sentenceBreak = endsSentence(open.text) && (gap > sentenceBreakGap || startsNewSentence)
            let fits = mergedEnd - open.start < maxDuration && mergedText.count < maxCharacters
            if gap < maxMergeGap && !sentenceBreak && fits {
                current = Draft(start: open.start, end: mergedEnd, text: mergedText)
            } else {
                drafts.append(open)
                current = Draft(start: piece.start, end: piece.end, text: piece.text)
            }
        }
        if let open = current { drafts.append(open) }

        return drafts.map { draft in
            Utterance(id: 0,
                      segmentID: segmentID,
                      startedAt: segmentStart.addingTimeInterval(draft.start),
                      endedAt: segmentStart.addingTimeInterval(max(draft.end, draft.start)),
                      text: draft.text,
                      speaker: nil)
        }
    }

    /// Trims and collapses whitespace, drops empty pieces, splits over-long ones, sorts by time.
    private static func prepare(_ pieces: [TranscriptPiece]) -> [TranscriptPiece] {
        var cleaned: [TranscriptPiece] = []
        for piece in pieces {
            let text = piece.text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
            guard !text.isEmpty, piece.start.isFinite else { continue }
            let start = max(0, piece.start)
            let end = piece.end.isFinite ? max(start, piece.end) : start
            cleaned.append(contentsOf: splitIfLong(TranscriptPiece(start: start, end: end, text: text)))
        }
        // Stable sort by start time.
        return cleaned.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.start != rhs.element.start { return lhs.element.start < rhs.element.start }
                return lhs.offset < rhs.offset
            }
            .map { $0.element }
    }

    /// Splits a piece that alone exceeds the utterance limits at sentence (then word) boundaries,
    /// spreading its time range proportionally to the text length.
    private static func splitIfLong(_ piece: TranscriptPiece) -> [TranscriptPiece] {
        let duration = piece.end - piece.start
        guard piece.text.count >= maxCharacters || duration >= maxDuration else { return [piece] }
        var parts: [String] = []
        for sentence in sentences(in: piece.text) {
            if sentence.count >= maxCharacters {
                parts.append(contentsOf: wordChunks(sentence, limit: maxCharacters - 1))
            } else {
                parts.append(sentence)
            }
        }
        guard parts.count > 1 else { return [piece] }
        let totalCharacters = parts.reduce(0) { $0 + $1.count }
        guard totalCharacters > 0 else { return [piece] }

        var result: [TranscriptPiece] = []
        var consumed = 0
        for part in parts {
            let partStart = piece.start + duration * Double(consumed) / Double(totalCharacters)
            consumed += part.count
            let partEnd = piece.start + duration * Double(consumed) / Double(totalCharacters)
            result.append(TranscriptPiece(start: partStart, end: partEnd, text: part))
        }
        return result
    }

    private static func sentences(in text: String) -> [String] {
        let characters = Array(text)
        var result: [String] = []
        var current = ""
        for (index, character) in characters.enumerated() {
            current.append(character)
            guard sentenceTerminators.contains(character) else { continue }
            let atBoundary = index + 1 >= characters.count
                || characters[index + 1].isWhitespace
                || unspacedTerminators.contains(character)
            if atBoundary {
                let sentence = current.trimmingCharacters(in: .whitespaces)
                if !sentence.isEmpty { result.append(sentence) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespaces)
        if !tail.isEmpty { result.append(tail) }
        return result
    }

    private static func wordChunks(_ text: String, limit: Int) -> [String] {
        let size = max(1, limit)
        var chunks: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            if word.count > size {
                // Unspaced scripts or very long tokens: hard split.
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
                var remainder: Substring = word
                while remainder.count > size {
                    chunks.append(String(remainder.prefix(size)))
                    remainder = remainder.dropFirst(size)
                }
                current = String(remainder)
                continue
            }
            if current.isEmpty {
                current = String(word)
            } else if current.count + 1 + word.count > size {
                chunks.append(current)
                current = String(word)
            } else {
                current += " " + String(word)
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private static func join(_ left: String, _ right: String) -> String {
        guard let last = left.last, let first = right.first else { return left + right }
        if attachingPunctuation.contains(first) || openingPunctuation.contains(last) {
            return left + right
        }
        if isUnspacedScript(last) && isUnspacedScript(first) {
            return left + right
        }
        return left + " " + right
    }

    private static func endsSentence(_ text: String) -> Bool {
        var trimmed = Substring(text)
        while let last = trimmed.last, closingQuotes.contains(last) {
            trimmed = trimmed.dropLast()
        }
        guard let last = trimmed.last else { return false }
        return sentenceTerminators.contains(last)
    }

    /// Scripts written without spaces between words (CJK, kana, Thai).
    private static func isUnspacedScript(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x0E00...0x0E7F,     // Thai
             0x3000...0x303F,     // CJK symbols and punctuation
             0x3040...0x309F,     // Hiragana
             0x30A0...0x30FF,     // Katakana
             0x3400...0x4DBF,     // CJK extension A
             0x4E00...0x9FFF,     // CJK unified ideographs
             0xF900...0xFAFF,     // CJK compatibility ideographs
             0xFF00...0xFFEF:     // Half/full-width forms
            return true
        default:
            return false
        }
    }
}
