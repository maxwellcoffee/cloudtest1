//  SegmentQueue.swift
//  Earshot (watchOS)
//
//  Durable store-and-forward queue for recorded audio plus an outbox for small
//  JSON messages (answers, requests, bookmarks).
//
//  On disk (Application Support/Queue):
//    <id>.m4a + <id>.json   one finished segment and its SegmentMeta
//    outbox.json            pending answers / requests / bookmarks
//    upload-state.json      per-segment rejection and failure counts
//
//  A segment's files are deleted only after the Mac answered SegmentAck.accepted
//  for that id (or when the 2 GB storage cap, or a nearly full watch, forces the
//  quietest ones out).

import AVFoundation
import Combine
import Foundation

// MARK: - Paths

enum WatchPaths {
    static var applicationSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return ensureDirectory(base)
    }

    /// Segment files that are still being written.
    static var recording: URL {
        ensureDirectory(applicationSupport.appendingPathComponent("Recording", isDirectory: true))
    }

    /// Finished segments waiting for upload, and the outbox.
    static var queue: URL {
        ensureDirectory(applicationSupport.appendingPathComponent("Queue", isDirectory: true))
    }

    @discardableResult
    static func ensureDirectory(_ url: URL) -> URL {
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            } catch {
                WatchLog.error("Couldn't create \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return url
    }

    static func fileSize(_ url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }
}

// MARK: - Outbox model

enum OutboxPayload: Codable, Hashable {
    case answer(PromptAnswer)
    case request(WatchRequest)
    case bookmark(Bookmark)
}

struct OutboxItem: Codable, Hashable, Identifiable {
    var id: String
    var createdAt: Date
    var payload: OutboxPayload
    var attempts: Int
}

/// A finished segment waiting on disk.
struct QueuedSegment: Hashable, Identifiable {
    var meta: SegmentMeta
    var audioURL: URL
    var metaURL: URL
    var bytes: Int64
    var id: String { meta.id }
}

// MARK: - Queue

@MainActor
final class SegmentQueue: ObservableObject {
    /// Total size of queued audio before the quietest segments are deleted.
    static let diskCapBytes: Int64 = 2 * 1024 * 1024 * 1024

    @Published private(set) var queuedSegments = 0
    @Published private(set) var queuedBytes: Int64 = 0
    @Published private(set) var outboxCount = 0
    @Published private(set) var lastUploadAt: Date? = nil
    @Published private(set) var lastError: String? = nil
    @Published private(set) var isUploading = false
    @Published private(set) var nextRetryAt: Date? = nil
    /// Acknowledgements for WatchRequests, by request id (shown in RequestView).
    @Published private(set) var requestAcks: [String: WatchRequestAck] = [:]

    /// Called when the Mac answers 401: the token is no longer valid.
    var onUnauthorized: (@MainActor () -> Void)?
    /// Called after a pass that delivered audio (the radio is awake right then).
    var onSegmentsUploaded: (@MainActor () -> Void)?

    let queueDirectory: URL
    let recordingDirectory: URL

    private struct PassOptions {
        var ignoreBackoff = false
        var forceSegments = false
        var includeSegments = true
        var deadline: Date?

        func merged(with other: PassOptions) -> PassOptions {
            var result = PassOptions()
            result.ignoreBackoff = ignoreBackoff || other.ignoreBackoff
            result.forceSegments = forceSegments || other.forceSegments
            result.includeSegments = includeSegments || other.includeSegments
            if let a = deadline, let b = other.deadline {
                result.deadline = max(a, b)
            } else {
                result.deadline = nil
            }
            return result
        }
    }

    private enum FailureAction { case stop, skip }
    private enum UploadOutcome { case accepted, skipped, stop }

    /// Per-segment upload trouble (upload-state.json).
    private struct UploadState: Codable {
        /// The Mac refused the segment as it is (HTTP 400, 413, 422): sending it again won't help.
        var rejections: [String: Int] = [:]
        /// The Mac failed to store it (HTTP 5xx) or the upload timed out: it may work later.
        var failures: [String: Int] = [:]
    }

    private static let backoffSteps: [TimeInterval] = [15, 30, 60, 120, 300]
    private static let batchAge: TimeInterval = 5 * 60
    private static let reservedFiles: Set<String> = ["outbox.json", "upload-state.json"]
    /// HTTP statuses that mean "this item is unacceptable as it is". Any other non-transient
    /// status (403, 404, 405, …) means something other than Earshot answered: keep everything.
    private static let rejectionStatuses: Set<Int> = [400, 413, 422]
    /// A segment rejected this often is sent again only by "Sync now".
    private static let parkAfterRejections = 3
    /// A spoken answer waits at most this long for its audio to reach the Mac first.
    private static let voiceAnswerHoldLimit: TimeInterval = 15 * 60
    /// The Mac's default voice window, for answers that don't say.
    private static let defaultVoiceWindow: TimeInterval = 25
    /// Free space left on the watch for the file being written and for the system.
    private static let freeSpaceReserve: Int64 = 100 * 1024 * 1024
    /// Background time asked for by `uploadSoon(reason:)`.
    private static let expiringActivitySeconds: TimeInterval = 25
    private enum Keys {
        static let lastUploadAt = "queue.lastUploadAt"
    }

    private let client: MacClient
    private let deviceName: String
    private let outboxURL: URL
    private let stateURL: URL

    private var segments: [QueuedSegment] = []
    private var outbox: [OutboxItem] = []
    private var uploadState = UploadState()
    /// When an answer last reached the Mac, by prompt id (this run only).
    private var answerDeliveries: [String: Date] = [:]

    private var pending: PassOptions?
    private var running = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var backoffStep = 0
    private var backoffUntil: Date?
    private var retryTask: Task<Void, Never>?

    init(client: MacClient, deviceName: String) {
        self.client = client
        self.deviceName = deviceName
        let queueDir = WatchPaths.queue
        queueDirectory = queueDir
        recordingDirectory = WatchPaths.recording
        outboxURL = queueDir.appendingPathComponent("outbox.json")
        stateURL = queueDir.appendingPathComponent("upload-state.json")
        lastUploadAt = UserDefaults.standard.object(forKey: Keys.lastUploadAt) as? Date
        loadOutbox()
        loadUploadState()
        rebuildIndex()
    }

    // MARK: Queries

    var oldestSegmentDate: Date? { segments.first?.meta.startedAt }

    /// A pass is running or waiting to run (the running loop also flushes the
    /// outbox between segment uploads).
    var isBusy: Bool { running || pending != nil }

    func hasPendingAnswer(for promptID: String) -> Bool {
        outbox.contains { item in
            if case .answer(let answer) = item.payload { return answer.promptID == promptID }
            return false
        }
    }

    func isPending(requestID: String) -> Bool {
        outbox.contains { item in
            if case .request(let request) = item.payload { return request.id == requestID }
            return false
        }
    }

    /// When an answer to `promptID` last reached the Mac since launch, if it did.
    func lastAnswerDelivery(for promptID: String) -> Date? {
        answerDeliveries[promptID]
    }

    // MARK: Enqueue

    /// Takes ownership of a finished, closed audio file and queues it for upload.
    func enqueueSegment(audioAt source: URL, meta: SegmentMeta) {
        let fm = FileManager.default
        let audioURL = queueDirectory.appendingPathComponent("\(meta.id).m4a")
        let metaURL = queueDirectory.appendingPathComponent("\(meta.id).json")
        do {
            let data = try EarshotAPI.makeEncoder().encode(meta)
            try data.write(to: metaURL, options: .atomic)
            if source.standardizedFileURL != audioURL.standardizedFileURL {
                if fm.fileExists(atPath: audioURL.path) { try fm.removeItem(at: audioURL) }
                try fm.moveItem(at: source, to: audioURL)
            }
        } catch {
            // The audio stays in Recording/ and is recovered at the next launch.
            try? fm.removeItem(at: metaURL)
            WatchLog.error("Couldn't queue segment \(meta.id): \(error.localizedDescription)")
            lastError = "Couldn't queue audio: \(error.localizedDescription)"
            return
        }
        segments.removeAll { $0.id == meta.id }
        segments.append(QueuedSegment(meta: meta, audioURL: audioURL, metaURL: metaURL,
                                      bytes: WatchPaths.fileSize(audioURL)))
        segments.sort { $0.meta.startedAt < $1.meta.startedAt }
        enforceDiskCap()
        refreshStats()
        WatchLog.info("Queued segment \(meta.id) (\(Int(meta.duration)) s, \(meta.reason.rawValue))")
        kick()
    }

    /// Queues a small message for the Mac and tries to deliver it right away.
    func enqueue(_ payload: OutboxPayload) {
        outbox.append(OutboxItem(id: UUID().uuidString, createdAt: Date(), payload: payload, attempts: 0))
        saveOutbox()
        refreshStats()
        kick(ignoreBackoff: true)
    }

    // MARK: Upload scheduling

    /// Schedules an upload pass (coalesced with any pass already waiting).
    /// `forceSegments` uploads even a single fresh segment ("Sync now").
    func kick(ignoreBackoff: Bool = false, forceSegments: Bool = false,
              includeSegments: Bool = true, deadline: Date? = nil) {
        schedule(PassOptions(ignoreBackoff: ignoreBackoff, forceSegments: forceSegments,
                             includeSegments: includeSegments, deadline: deadline))
    }

    /// Uploads now and asks watchOS for a little background time to finish. After Stop, a
    /// privacy pause or an interruption the app no longer records, so it would otherwise be
    /// suspended within seconds of the wrist going down, with the last segment still queued.
    func uploadSoon(reason: String) {
        let seconds = Self.expiringActivitySeconds
        let waitLimit = seconds + 2
        let finished = DispatchSemaphore(value: 0)
        ProcessInfo.processInfo.performExpiringActivity(withReason: reason) { expired in
            guard !expired else {
                // Out of time (or no time granted): let the first call return.
                finished.signal()
                return
            }
            Task { @MainActor in
                await self.runPass(ignoreBackoff: true, forceSegments: true, includeSegments: true,
                                   deadline: Date().addingTimeInterval(seconds))
                finished.signal()
            }
            // The background time lasts as long as this block runs.
            _ = finished.wait(timeout: .now() + waitLimit)
        }
    }

    /// Schedules a pass and waits until it has finished.
    func runPass(ignoreBackoff: Bool, forceSegments: Bool, includeSegments: Bool, deadline: Date?) async {
        let options = PassOptions(ignoreBackoff: ignoreBackoff, forceSegments: forceSegments,
                                  includeSegments: includeSegments, deadline: deadline)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            waiters.append(continuation)
            schedule(options)
        }
    }

    private func schedule(_ options: PassOptions) {
        if let existing = pending {
            pending = existing.merged(with: options)
        } else {
            pending = options
        }
        guard !running else { return }
        running = true
        Task { await self.drain() }
    }

    private func drain() async {
        while let options = pending {
            pending = nil
            let waiting = waiters
            waiters = []
            await pass(options)
            for waiter in waiting { waiter.resume() }
        }
        running = false
    }

    // MARK: The pass

    private func pass(_ options: PassOptions) async {
        guard client.isPaired else { return }
        if !options.ignoreBackoff, let until = backoffUntil, until.timeIntervalSinceNow > 1 { return }
        guard !outbox.isEmpty || (options.includeSegments && !segments.isEmpty) else { return }

        isUploading = true
        defer { isUploading = false }

        guard await flushOutbox(deadline: options.deadline) else { return }
        guard options.includeSegments, shouldUploadSegments(force: options.forceSegments) else { return }

        var uploaded = 0
        defer { if uploaded > 0 { onSegmentsUploaded?() } }
        // The next segment is picked afresh each time, so a voice answer queued while a long
        // backlog uploads goes next instead of after the whole backlog.
        var tried = Set<String>()
        while let segment = nextSegment(excluding: tried, includeParked: options.forceSegments) {
            if let deadline = options.deadline, Date().addingTimeInterval(8) > deadline { return }
            tried.insert(segment.id)
            // Answers and requests jump ahead of a long audio backlog.
            guard await flushOutbox(deadline: options.deadline) else { return }
            guard segments.contains(where: { $0.id == segment.id }) else { continue }
            switch await upload(segment) {
            case .accepted:
                uploaded += 1
            case .skipped:
                continue
            case .stop:
                return
            }
        }
        // A spoken answer held back for its audio goes out right after the audio.
        _ = await flushOutbox(deadline: options.deadline)
    }

    /// Sends outbox items oldest first (a spoken answer waits for its audio). Returns false
    /// when the pass should stop.
    private func flushOutbox(deadline: Date?) async -> Bool {
        while let item = outbox.first(where: { !isWaitingForAudio($0) }) {
            if let deadline, Date().addingTimeInterval(2) > deadline { return false }
            do {
                switch item.payload {
                case .answer(let answer):
                    try await client.send(answer: answer)
                    noteAnswerDelivered(answer.promptID)
                case .request(let request):
                    let ack = try await client.send(request: request)
                    requestAcks[request.id] = ack
                case .bookmark(let bookmark):
                    try await client.send(bookmark: bookmark)
                }
                removeOutboxItem(item.id)
                noteSuccess()
            } catch {
                switch classify(error) {
                case .stop:
                    if let index = outbox.firstIndex(where: { $0.id == item.id }) {
                        outbox[index].attempts += 1
                        saveOutbox()
                    }
                    return false
                case .skip:
                    // The Mac will never accept this item as it is; drop it so it can't block the outbox.
                    WatchLog.error("Dropping outbox item \(item.id): \(MacClient.describe(error))")
                    if case .request(let request) = item.payload {
                        requestAcks[request.id] = WatchRequestAck(id: request.id, accepted: false,
                                                                  message: MacClient.describe(error))
                    }
                    removeOutboxItem(item.id)
                }
            }
        }
        return true
    }

    /// A spoken answer is held back while audio covering its window is still on the watch:
    /// the Mac settles a voice answer soon after it arrives when no audio for the window has
    /// reached it yet. Held at most `voiceAnswerHoldLimit` (the audio may be stuck).
    private func isWaitingForAudio(_ item: OutboxItem) -> Bool {
        guard case .answer(let answer) = item.payload, answer.mode == .voiceWindow,
              Date().timeIntervalSince(item.createdAt) < Self.voiceAnswerHoldLimit else { return false }
        let start = answer.answeredAt
        let end = start.addingTimeInterval(answer.voiceWindowSeconds ?? Self.defaultVoiceWindow)
        return segments.contains { segment in
            !isParked(segment.id)
                && segment.meta.startedAt <= end
                && segment.meta.startedAt.addingTimeInterval(segment.meta.duration) >= start
        }
    }

    /// Batch radio use: two or more fresh segments, an old one, one that ends a stretch of
    /// recording (stop, pause, interruption, low battery, voice answer), or an explicit request.
    private func shouldUploadSegments(force: Bool) -> Bool {
        if force { return !segments.isEmpty }
        let waiting = segments.filter { !isParked($0.id) }
        guard let oldest = waiting.first else { return false }
        // Segments that failed before don't make a batch on their own; they go along with one.
        let fresh = waiting.filter { troubleCount($0.id) == 0 }
        if fresh.count >= 2 { return true }
        if fresh.contains(where: { $0.meta.reason != .rotation }) { return true }
        if waiting.contains(where: { $0.meta.reason == .voiceAnswer }) { return true }
        let endedAt = oldest.meta.startedAt.addingTimeInterval(oldest.meta.duration)
        return Date().timeIntervalSince(endedAt) >= Self.batchAge
    }

    /// The next segment to send: voice answers first (the Mac is waiting for them), then
    /// oldest first. Segments that failed or were rejected before go last, least troubled
    /// first, so one bad segment never blocks the queue; parked ones only when forced.
    private func nextSegment(excluding tried: Set<String>, includeParked: Bool) -> QueuedSegment? {
        segments
            .filter { !tried.contains($0.id) && (includeParked || !isParked($0.id)) }
            .min { a, b in
                let aTrouble = troubleCount(a.id)
                let bTrouble = troubleCount(b.id)
                if aTrouble != bTrouble { return aTrouble < bTrouble }
                let aVoice = a.meta.reason == .voiceAnswer
                let bVoice = b.meta.reason == .voiceAnswer
                if aVoice != bVoice { return aVoice }
                return a.meta.startedAt < b.meta.startedAt
            }
    }

    private func troubleCount(_ id: String) -> Int {
        (uploadState.rejections[id] ?? 0) + (uploadState.failures[id] ?? 0)
    }

    private func isParked(_ id: String) -> Bool {
        (uploadState.rejections[id] ?? 0) >= Self.parkAfterRejections
    }

    private func upload(_ segment: QueuedSegment) async -> UploadOutcome {
        guard FileManager.default.fileExists(atPath: segment.audioURL.path) else {
            WatchLog.error("Audio for segment \(segment.id) vanished; removing its record")
            removeSegment(segment.id)
            return .skipped
        }
        do {
            let ack = try await client.uploadSegment(fileURL: segment.audioURL, meta: segment.meta)
            if ack.accepted && ack.id == segment.id {
                removeSegment(segment.id)
                let now = Date()
                lastUploadAt = now
                UserDefaults.standard.set(now, forKey: Keys.lastUploadAt)
                noteSuccess()
                return .accepted
            }
            noteFailure(segment.id)
            let reason = ack.message ?? (ack.id == segment.id ? "Mac couldn't store the audio" : "Mac acknowledged a different segment")
            WatchLog.error("Segment \(segment.id) not accepted: \(reason)")
            applyBackoff(reason)
            return .stop
        } catch {
            switch classify(error) {
            case .stop:
                // The Mac failed on this segment (5xx, e.g. a failed write) or it timed out:
                // the next pass tries the other segments first instead of stalling on it.
                if Self.isSegmentFailure(error) { noteFailure(segment.id) }
                return .stop
            case .skip:
                let count = noteRejection(segment.id)
                lastError = "Mac rejected a segment: \(MacClient.describe(error))"
                let parked = count >= Self.parkAfterRejections ? "; it is sent again only by Sync now" : ""
                WatchLog.error("Segment \(segment.id) rejected \(count)×: \(MacClient.describe(error))\(parked)")
                return .skipped
            }
        }
    }

    private static func isSegmentFailure(_ error: Error) -> Bool {
        if let clientError = error as? MacClientError, case .http(let status, _) = clientError {
            return status >= 500
        }
        if let urlError = error as? URLError { return urlError.code == .timedOut }
        return false
    }

    private func classify(_ error: Error) -> FailureAction {
        if let clientError = error as? MacClientError {
            switch clientError {
            case .unauthorized:
                lastError = "Your Mac no longer recognises this watch. Pair again."
                onUnauthorized?()
                return .stop
            case .notPaired:
                return .stop
            case .invalidURL:
                applyBackoff("The Mac address isn't valid")
                return .stop
            case .http(let status, _) where !MacClient.isTransient(error) && !Self.rejectionStatuses.contains(status):
                // Whatever answered (a wrong address, a proxy or a tunnel) refuses every
                // request alike: keep the item and retry later instead of dropping it.
                applyBackoff("\(MacClient.describe(error)) (check the Mac address in Settings)")
                return .stop
            default:
                break
            }
        }
        if MacClient.isTransient(error) {
            applyBackoff(MacClient.describe(error))
            return .stop
        }
        return .skip
    }

    // MARK: Backoff

    private func applyBackoff(_ reason: String) {
        let steps = Self.backoffSteps
        let delay = steps[min(backoffStep, steps.count - 1)]
        backoffStep = min(backoffStep + 1, steps.count - 1)
        let until = Date().addingTimeInterval(delay)
        backoffUntil = until
        nextRetryAt = until
        lastError = "\(reason) — retrying in \(Self.delayText(delay))"
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.kick()
        }
    }

    private func noteSuccess() {
        backoffStep = 0
        backoffUntil = nil
        nextRetryAt = nil
        lastError = nil
        retryTask?.cancel()
        retryTask = nil
    }

    private static func delayText(_ delay: TimeInterval) -> String {
        delay < 60 ? "\(Int(delay)) s" : "\(Int(delay / 60)) min"
    }

    // MARK: Storage cap

    private func enforceDiskCap() {
        var total = segments.reduce(Int64(0)) { $0 + $1.bytes }
        var cap = Self.diskCapBytes
        if let free = Self.freeBytes(at: queueDirectory) {
            // On a nearly full watch, make room before writing new audio fails.
            cap = min(cap, max(0, total + free - Self.freeSpaceReserve))
        }
        guard total > cap else { return }
        let victims = segments.sorted { a, b in
            if a.meta.speechRatio != b.meta.speechRatio { return a.meta.speechRatio < b.meta.speechRatio }
            return a.meta.startedAt < b.meta.startedAt
        }
        var deleted = 0
        for victim in victims {
            guard total > cap, segments.count > 1 else { break }
            total -= victim.bytes
            removeSegment(victim.id)
            deleted += 1
            WatchLog.error("Storage cap reached: deleted segment \(victim.id) from \(victim.meta.startedAt) "
                           + "(speech \(Int(victim.meta.speechRatio * 100))%, \(victim.bytes) bytes)")
        }
        if deleted > 0 {
            lastError = "Watch storage full — deleted \(deleted) of the quietest segments"
        }
    }

    /// Free space on the volume holding `url`; nil when it can't be read.
    private static func freeBytes(at url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfFileSystem(forPath: url.path),
              let free = attributes[.systemFreeSize] as? NSNumber else { return nil }
        return free.int64Value
    }

    // MARK: Index & recovery

    private func removeSegment(_ id: String) {
        guard let index = segments.firstIndex(where: { $0.id == id }) else { return }
        let segment = segments.remove(at: index)
        try? FileManager.default.removeItem(at: segment.audioURL)
        try? FileManager.default.removeItem(at: segment.metaURL)
        let hadRejections = uploadState.rejections.removeValue(forKey: id) != nil
        let hadFailures = uploadState.failures.removeValue(forKey: id) != nil
        if hadRejections || hadFailures { saveUploadState() }
        refreshStats()
    }

    private func refreshStats() {
        queuedSegments = segments.count
        queuedBytes = segments.reduce(Int64(0)) { $0 + $1.bytes }
        outboxCount = outbox.count
    }

    /// Scans the queue directory and repairs anything a crash left behind:
    /// metadata whose audio is still in Recording/, audio without metadata, and
    /// finished files in Recording/ that never made it into the queue.
    private func rebuildIndex() {
        let fm = FileManager.default
        let decoder = EarshotAPI.makeDecoder()
        let queueFiles = (try? fm.contentsOfDirectory(at: queueDirectory, includingPropertiesForKeys: nil,
                                                      options: [.skipsHiddenFiles])) ?? []
        var metaFiles: [String: URL] = [:]
        var audioFiles: [String: URL] = [:]
        for file in queueFiles {
            let id = file.deletingPathExtension().lastPathComponent
            switch file.pathExtension.lowercased() {
            case "json" where !Self.reservedFiles.contains(file.lastPathComponent):
                metaFiles[id] = file
            case "m4a":
                audioFiles[id] = file
            default:
                break
            }
        }

        var result: [QueuedSegment] = []
        for (id, metaURL) in metaFiles {
            guard let data = try? Data(contentsOf: metaURL),
                  let meta = try? decoder.decode(SegmentMeta.self, from: data) else {
                WatchLog.error("Unreadable metadata \(metaURL.lastPathComponent); rebuilding it from the audio")
                try? fm.removeItem(at: metaURL)
                continue
            }
            var audioURL = audioFiles.removeValue(forKey: id)
            if audioURL == nil {
                let stranded = recordingDirectory.appendingPathComponent("\(id).m4a")
                let destination = queueDirectory.appendingPathComponent("\(id).m4a")
                if fm.fileExists(atPath: stranded.path) {
                    do {
                        try fm.moveItem(at: stranded, to: destination)
                        audioURL = destination
                    } catch {
                        WatchLog.error("Couldn't move stranded audio \(id): \(error.localizedDescription)")
                    }
                }
            }
            guard let audio = audioURL else {
                WatchLog.error("Metadata \(id) has no audio; removing it")
                try? fm.removeItem(at: metaURL)
                continue
            }
            result.append(QueuedSegment(meta: meta, audioURL: audio, metaURL: metaURL, bytes: WatchPaths.fileSize(audio)))
        }

        // Audio in the queue without metadata (metadata lost or unreadable).
        for (id, audioURL) in audioFiles {
            if let recovered = recover(audioAt: audioURL, id: id, moveIntoQueue: false) {
                result.append(recovered)
            }
        }

        // Finished files left in Recording/ by a crash between closing and queueing.
        let recordingFiles = (try? fm.contentsOfDirectory(at: recordingDirectory, includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles])) ?? []
        for file in recordingFiles where file.pathExtension.lowercased() == "m4a" {
            let id = file.deletingPathExtension().lastPathComponent
            guard !result.contains(where: { $0.id == id }) else {
                try? fm.removeItem(at: file)
                continue
            }
            if let recovered = recover(audioAt: file, id: id, moveIntoQueue: true) {
                result.append(recovered)
            }
        }

        segments = result.sorted { $0.meta.startedAt < $1.meta.startedAt }
        let known = Set(segments.map(\.id))
        let rejectionsBefore = uploadState.rejections.count
        let failuresBefore = uploadState.failures.count
        uploadState.rejections = uploadState.rejections.filter { known.contains($0.key) }
        uploadState.failures = uploadState.failures.filter { known.contains($0.key) }
        if uploadState.rejections.count != rejectionsBefore || uploadState.failures.count != failuresBefore {
            saveUploadState()
        }
        enforceDiskCap()
        refreshStats()
        if !segments.isEmpty {
            WatchLog.info("Queue holds \(segments.count) segments (\(queuedBytes) bytes) and \(outbox.count) messages")
        }
    }

    /// Rebuilds metadata for a readable audio file. Unreadable files (the app died
    /// while they were open, so the MP4 container was never finalised) are deleted.
    private func recover(audioAt url: URL, id: String, moveIntoQueue: Bool) -> QueuedSegment? {
        let fm = FileManager.default
        guard let file = try? AVAudioFile(forReading: url) else {
            WatchLog.error("Discarding unreadable audio \(url.lastPathComponent) (recording was cut off)")
            try? fm.removeItem(at: url)
            return nil
        }
        let rate = file.processingFormat.sampleRate
        guard rate > 0, file.length > 0 else {
            try? fm.removeItem(at: url)
            return nil
        }
        let duration = Double(file.length) / rate
        let attributes = try? fm.attributesOfItem(atPath: url.path)
        let created = (attributes?[.creationDate] as? Date)
            ?? (attributes?[.modificationDate] as? Date)?.addingTimeInterval(-duration)
            ?? Date().addingTimeInterval(-duration)
        // Power figures are unknown for recovered audio; these match the protocol's
        // header defaults, and speechRatio 1 makes sure the Mac transcribes it.
        let meta = SegmentMeta(id: id, device: deviceName, startedAt: created, duration: duration,
                               avgPower: -160, peakPower: -160, speechRatio: 1, reason: .interruption)
        let audioURL = queueDirectory.appendingPathComponent("\(id).m4a")
        let metaURL = queueDirectory.appendingPathComponent("\(id).json")
        do {
            let data = try EarshotAPI.makeEncoder().encode(meta)
            try data.write(to: metaURL, options: .atomic)
            if moveIntoQueue {
                if fm.fileExists(atPath: audioURL.path) { try fm.removeItem(at: audioURL) }
                try fm.moveItem(at: url, to: audioURL)
            }
        } catch {
            WatchLog.error("Couldn't recover \(url.lastPathComponent): \(error.localizedDescription)")
            try? fm.removeItem(at: metaURL)
            return nil
        }
        WatchLog.info("Recovered segment \(id) (\(Int(duration)) s)")
        return QueuedSegment(meta: meta, audioURL: audioURL, metaURL: metaURL, bytes: WatchPaths.fileSize(audioURL))
    }

    // MARK: Persistence

    private func removeOutboxItem(_ id: String) {
        outbox.removeAll { $0.id == id }
        saveOutbox()
        refreshStats()
    }

    private func loadOutbox() {
        guard let data = try? Data(contentsOf: outboxURL) else { return }
        do {
            outbox = try EarshotAPI.makeDecoder().decode([OutboxItem].self, from: data)
        } catch {
            WatchLog.error("Outbox unreadable, starting empty: \(error.localizedDescription)")
            let backup = queueDirectory.appendingPathComponent("outbox-corrupt-\(Int(Date().timeIntervalSince1970)).bak")
            try? FileManager.default.moveItem(at: outboxURL, to: backup)
            outbox = []
        }
    }

    private func saveOutbox() {
        do {
            let data = try EarshotAPI.makeEncoder().encode(outbox)
            try data.write(to: outboxURL, options: .atomic)
        } catch {
            WatchLog.error("Couldn't save the outbox: \(error.localizedDescription)")
        }
    }

    private func noteAnswerDelivered(_ promptID: String) {
        let now = Date()
        answerDeliveries = answerDeliveries.filter { now.timeIntervalSince($0.value) < 3_600 }
        answerDeliveries[promptID] = now
    }

    private func noteFailure(_ id: String) {
        uploadState.failures[id, default: 0] += 1
        saveUploadState()
    }

    /// Returns how often the segment has been rejected.
    private func noteRejection(_ id: String) -> Int {
        let count = (uploadState.rejections[id] ?? 0) + 1
        uploadState.rejections[id] = count
        saveUploadState()
        return count
    }

    private func loadUploadState() {
        guard let data = try? Data(contentsOf: stateURL) else { return }
        let decoder = JSONDecoder()
        if let legacy = try? decoder.decode([String: Int].self, from: data) {
            // Earlier versions stored rejection counts only.
            uploadState = UploadState(rejections: legacy, failures: [:])
        } else if let decoded = try? decoder.decode(UploadState.self, from: data) {
            uploadState = decoded
        }
    }

    private func saveUploadState() {
        do {
            let data = try JSONEncoder().encode(uploadState)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            WatchLog.error("Couldn't save upload state: \(error.localizedDescription)")
        }
    }
}
