//  WatchStore.swift
//  Earshot (watchOS)
//
//  App state shared by every screen, the app delegate and the notification
//  delegate: pairing, persisted settings, the 60-second sync loop, and the
//  wiring between the recorder, the upload queue and the prompt inbox.

import Combine
import Foundation
import Security
import SwiftUI
import UserNotifications
import WatchKit

enum WatchTab: Hashable {
    case record, inbox, today, settings
}

enum PairingStatus: Equatable {
    case unpaired
    case paired
    /// The Mac rejected the token; the user must pair again (queued audio is kept).
    case needsRepair
}

@MainActor
final class WatchStore: ObservableObject {
    static let shared = WatchStore()

    let client: MacClient
    let queue: SegmentQueue
    let recorder: AudioCapture
    let prompts: PromptCenter

    // Navigation
    @Published var selectedTab: WatchTab = .record
    @Published var inboxPath: [String] = []

    // Pairing & sync
    @Published private(set) var pairingStatus: PairingStatus
    @Published private(set) var macAddress: String
    @Published private(set) var macName: String? = nil
    @Published private(set) var isPairing = false
    @Published private(set) var pairingMessage: String? = nil
    @Published private(set) var lastSyncAt: Date? = nil
    @Published private(set) var lastSyncError: String? = nil
    @Published private(set) var isSyncing = false

    // Data pushed by the Mac
    @Published private(set) var remoteSettings: RemoteWatchSettings
    @Published private(set) var today: TodaySnapshot

    @Published private(set) var isAppActive = false
    @Published private(set) var notificationsAllowed: Bool? = nil

    let deviceName: String
    let appVersion: String

    private enum Keys {
        static let macAddress = "store.macAddress"
        static let macName = "store.macName"
        static let isPaired = "store.isPaired"
        static let remoteSettings = "store.remoteSettings"
        static let today = "store.today"
        static let lastSyncAt = "store.lastSyncAt"
    }

    private var tickTask: Task<Void, Never>?

    private init() {
        let defaults = UserDefaults.standard
        let name = WKInterfaceDevice.current().name
        let settings = WatchStore.loadJSON(RemoteWatchSettings.self, key: Keys.remoteSettings) ?? .standard
        let address = defaults.string(forKey: Keys.macAddress) ?? ""
        deviceName = name
        appVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
        remoteSettings = settings
        today = WatchStore.loadJSON(TodaySnapshot.self, key: Keys.today) ?? .empty
        macAddress = address

        let client = MacClient()
        let queue = SegmentQueue(client: client, deviceName: name)
        self.client = client
        self.queue = queue
        recorder = AudioCapture(deviceName: name, settings: settings)
        prompts = PromptCenter(queue: queue)

        let token = TokenVault.read()
        let wasPaired = defaults.bool(forKey: Keys.isPaired)
        if let token, wasPaired {
            client.token = token
            pairingStatus = .paired
        } else if wasPaired {
            // Paired before, but the token can't be read (should not happen with
            // after-first-unlock keychain items). Ask for a new pairing.
            pairingStatus = .needsRepair
        } else {
            pairingStatus = .unpaired
        }
        client.setBaseURL(MacClient.baseURL(from: address))

        // Every stored property is initialised from here on.
        macName = defaults.string(forKey: Keys.macName)
        lastSyncAt = defaults.object(forKey: Keys.lastSyncAt) as? Date
        connect()
        startTicker()
    }

    // MARK: Lifecycle

    func scenePhaseChanged(_ phase: ScenePhase) {
        let active = phase == .active
        let wasActive = isAppActive
        isAppActive = active
        recorder.setForeground(active)
        guard active, !wasActive else { return }
        Task {
            await self.recorder.appBecameActive()
            await self.syncCycle(force: false)
        }
    }

    /// Work for a WKApplicationRefreshBackgroundTask: deliver messages, sync,
    /// then upload whatever fits before `deadline`.
    func performBackgroundRefresh(deadline: Date) async {
        recorder.periodicCheck()
        recorder.remindToResumeIfNeeded()
        prompts.refreshExpiry()
        guard pairingStatus == .paired, client.isPaired else { return }
        await queue.runPass(ignoreBackoff: true, forceSegments: false, includeSegments: false, deadline: deadline)
        await performSync()
        await queue.runPass(ignoreBackoff: true, forceSegments: true, includeSegments: true, deadline: deadline)
    }

    /// Delivers queued answers right away (used after a notification action).
    func flushOutboxQuickly(seconds: Double) async {
        let deadline = Date().addingTimeInterval(seconds)
        await awaitAtMost(seconds) { [weak self] in
            await self?.queue.runPass(ignoreBackoff: true, forceSegments: false,
                                      includeSegments: false, deadline: deadline)
        }
    }

    /// Runs `work` but returns after `seconds` at the latest; the work itself keeps going.
    func awaitAtMost(_ seconds: Double, _ work: @escaping @Sendable @MainActor () async -> Void) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let gate = OnceGate(continuation)
            Task { @MainActor in
                await work()
                gate.open()
            }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
                gate.open()
            }
        }
    }

    // MARK: Sync

    /// "Sync now" / "Upload now": ignores batching and backoff.
    func syncNow() async {
        await syncCycle(force: true)
    }

    /// Outbox first (answers before the Mac decides what to ask next), then /sync,
    /// then audio in the background.
    func syncCycle(force: Bool) async {
        guard pairingStatus == .paired, client.isPaired else { return }
        if !queue.isBusy {
            await queue.runPass(ignoreBackoff: force, forceSegments: false, includeSegments: false, deadline: nil)
        }
        await performSync()
        queue.kick(ignoreBackoff: force, forceSegments: force)
    }

    private func performSync() async {
        guard pairingStatus == .paired, client.isPaired, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        let delivered = prompts.deliveredIDsToReport()
        let report = WatchStatusReport(deviceName: deviceName,
                                       isRecording: recorder.isRecording,
                                       pausedUntil: recorder.pausedUntil,
                                       batteryLevel: WKInterfaceDevice.current().batteryLevel,
                                       queuedSegments: queue.queuedSegments,
                                       queuedBytes: queue.queuedBytes,
                                       lastSegmentAt: recorder.lastSegmentAt,
                                       recordedSecondsToday: recorder.todayTotalSeconds,
                                       appVersion: appVersion,
                                       deliveredPromptIDs: delivered)
        do {
            let response = try await client.sync(report)
            prompts.confirmReported(delivered)
            apply(response)
            let now = Date()
            lastSyncAt = now
            lastSyncError = nil
            UserDefaults.standard.set(now, forKey: Keys.lastSyncAt)
        } catch {
            if let clientError = error as? MacClientError, clientError == .unauthorized {
                handleUnauthorized()
                return
            }
            lastSyncError = MacClient.describe(error)
            WatchLog.info("Sync failed: \(MacClient.describe(error))")
        }
    }

    private func apply(_ response: SyncResponse) {
        if !response.macName.isEmpty, response.macName != macName {
            macName = response.macName
            UserDefaults.standard.set(response.macName, forKey: Keys.macName)
        }
        if response.settings != remoteSettings {
            remoteSettings = response.settings
            WatchStore.saveJSON(response.settings, key: Keys.remoteSettings)
            recorder.apply(response.settings)
        }
        if response.today != today {
            today = response.today
            WatchStore.saveJSON(response.today, key: Keys.today)
        }
        prompts.apply(response.prompts, serverTime: response.serverTime, appActive: isAppActive)
    }

    private func startTicker() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                guard let self else { return }
                await self.tick()
            }
        }
    }

    private func tick() async {
        recorder.periodicCheck()
        prompts.refreshExpiry()
        guard isAppActive || recorder.isRecording else { return }
        await syncCycle(force: false)
    }

    // MARK: Pairing

    func pair(address rawAddress: String, code rawCode: String) async {
        guard !isPairing else { return }
        let address = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = rawCode.filter { $0.isASCII && $0.isNumber }
        guard let url = MacClient.baseURL(from: address) else {
            pairingMessage = "Enter your Mac's address, for example 192.168.1.5."
            Haptics.failure()
            return
        }
        guard code.count == 6 else {
            pairingMessage = "Enter the 6-digit code shown on your Mac."
            Haptics.failure()
            return
        }

        isPairing = true
        pairingMessage = "Contacting your Mac…"
        defer { isPairing = false }

        do {
            let hello = try await client.hello(baseURL: url)
            guard hello.protocolVersion == EarshotAPI.protocolVersion else {
                pairingMessage = "\(hello.macName) speaks protocol v\(hello.protocolVersion); this watch speaks "
                    + "v\(EarshotAPI.protocolVersion). Update both apps."
                Haptics.failure()
                return
            }
            let response = try await client.pair(code: code, baseURL: url)
            TokenVault.write(response.token)
            client.setBaseURL(url)
            client.token = response.token

            let defaults = UserDefaults.standard
            macAddress = address
            macName = response.macName
            defaults.set(address, forKey: Keys.macAddress)
            defaults.set(response.macName, forKey: Keys.macName)
            defaults.set(true, forKey: Keys.isPaired)
            pairingStatus = .paired
            pairingMessage = "Paired with \(response.macName)."
            lastSyncError = nil
            Haptics.success()
            WatchLog.info("Paired with \(response.macName) at \(url.absoluteString)")
            await syncCycle(force: true)
        } catch {
            pairingMessage = pairingFailureMessage(error, address: address)
            Haptics.failure()
        }
    }

    /// Reaches the Mac without pairing and reports the round-trip time.
    func testConnection(address rawAddress: String) async -> String {
        let typed = rawAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let address = typed.isEmpty ? macAddress : typed
        guard let url = MacClient.baseURL(from: address) else { return "Enter a valid address first." }
        let started = Date()
        do {
            let hello = try await client.hello(baseURL: url)
            let milliseconds = Int(Date().timeIntervalSince(started) * 1000)
            var result = "Reached \(hello.macName) in \(milliseconds) ms."
            if hello.protocolVersion != EarshotAPI.protocolVersion {
                result += " Protocol v\(hello.protocolVersion) doesn't match this watch (v\(EarshotAPI.protocolVersion))."
            }
            return result
        } catch {
            return "\(MacClient.describe(error)) at \(url.absoluteString)."
        }
    }

    /// Forgets the Mac. Queued audio stays on the watch and uploads after pairing again.
    func unpair() {
        TokenVault.delete()
        client.token = nil
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: Keys.isPaired)
        defaults.removeObject(forKey: Keys.macName)
        defaults.removeObject(forKey: Keys.today)
        defaults.removeObject(forKey: Keys.lastSyncAt)
        pairingStatus = .unpaired
        macName = nil
        today = .empty
        lastSyncAt = nil
        lastSyncError = nil
        pairingMessage = nil
        inboxPath = []
        prompts.clearAll()
        WatchLog.info("Unpaired")
    }

    func handleUnauthorized() {
        guard pairingStatus == .paired else { return }
        TokenVault.delete()
        client.token = nil
        UserDefaults.standard.set(false, forKey: Keys.isPaired)
        pairingStatus = .needsRepair
        lastSyncError = "Your Mac no longer recognises this watch. Pair again."
        pairingMessage = nil
        Haptics.failure()
        WatchLog.error("Token rejected by the Mac; pairing required")
    }

    private func pairingFailureMessage(_ error: Error, address: String) -> String {
        if let clientError = error as? MacClientError {
            switch clientError {
            case .unauthorized, .http(403, _):
                return "That code didn't work. Check the code on your Mac — it changes every 10 minutes."
            case .http(429, _):
                return "Too many attempts. Wait a minute and try again."
            case .http(404, _):
                return "\(address) answered, but it isn't Earshot. Check the address and port."
            default:
                return clientError.errorDescription ?? "Pairing failed."
            }
        }
        if error is URLError {
            return "Can't reach \(address) (\(MacClient.describe(error))). Is the Mac awake and on the same network?"
        }
        return "Pairing failed: \(error.localizedDescription)"
    }

    // MARK: Actions from the UI

    /// "Mark": remember this moment.
    func markMoment() {
        queue.enqueue(.bookmark(Bookmark(kind: .bookmark)))
        Haptics.success()
    }

    /// Ask / Do / Note. Returns the request id so the UI can show its acknowledgement.
    @discardableResult
    func sendRequest(kind: WatchRequestKind, text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let request = WatchRequest(kind: kind, text: trimmed)
        queue.enqueue(.request(request))
        Haptics.success()
        return request.id
    }

    func openPrompt(_ id: String) {
        selectedTab = .inbox
        inboxPath = [id]
        prompts.dismissArrival()
    }

    // MARK: Notifications

    func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            if let error {
                WatchLog.error("Notification authorization failed: \(error.localizedDescription)")
            }
            Task { @MainActor in self?.notificationsAllowed = granted }
        }
    }

    /// From the notification delegate. Resume/info notifications carry no prompt id
    /// and simply open the app (which resumes recording when it becomes active).
    func handleNotificationResponse(promptID: String?, actionIdentifier: String, userText: String?) {
        guard let promptID else { return }
        if let toOpen = prompts.handleNotificationResponse(promptID: promptID, actionIdentifier: actionIdentifier,
                                                           userText: userText) {
            openPrompt(toOpen)
        }
    }

    // MARK: Wiring

    private func connect() {
        recorder.onSegment = { [weak self] url, meta in
            self?.queue.enqueueSegment(audioAt: url, meta: meta)
        }
        recorder.onBookmark = { [weak self] bookmark in
            self?.queue.enqueue(.bookmark(bookmark))
        }
        queue.onUnauthorized = { [weak self] in
            self?.handleUnauthorized()
        }
    }

    // MARK: Persistence helpers

    private static func loadJSON<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? EarshotAPI.makeDecoder().decode(type, from: data)
    }

    private static func saveJSON<T: Encodable>(_ value: T, key: String) {
        guard let data = try? EarshotAPI.makeEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Helpers

/// Resumes a continuation exactly once.
@MainActor
final class OnceGate {
    private var continuation: CheckedContinuation<Void, Never>?

    init(_ continuation: CheckedContinuation<Void, Never>) {
        self.continuation = continuation
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}

/// The pairing token lives in the keychain (readable after first unlock, so
/// background uploads work while the watch is locked on the wrist).
private enum TokenVault {
    private static let service = "com.earshot.watch.pairing"
    private static let account = "mac-token"
    /// Used only if the keychain refuses the item.
    private static let fallbackKey = "store.tokenFallback"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data,
           let token = String(data: data, encoding: .utf8), !token.isEmpty {
            return token
        }
        if status != errSecItemNotFound && status != errSecSuccess {
            WatchLog.error("Keychain read failed (\(status))")
        }
        return UserDefaults.standard.string(forKey: fallbackKey)
    }

    static func write(_ token: String) {
        _ = SecItemDelete(baseQuery as CFDictionary)
        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(token.utf8)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: fallbackKey)
        } else {
            WatchLog.error("Keychain write failed (\(status)); keeping the token in app preferences")
            UserDefaults.standard.set(token, forKey: fallbackKey)
        }
    }

    static func delete() {
        _ = SecItemDelete(baseQuery as CFDictionary)
        UserDefaults.standard.removeObject(forKey: fallbackKey)
    }
}
