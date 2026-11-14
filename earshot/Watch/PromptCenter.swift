//  PromptCenter.swift
//  Earshot (watchOS)
//
//  Prompts the Mac wants shown on the wrist: local persistence (open ones plus
//  24 h of history), in-app arrival haptics, local notifications with per-prompt
//  action categories, and turning answers into PromptAnswer outbox items.

import Combine
import Foundation
import UserNotifications

// MARK: - Local notifications

enum LocalNotifier {
    /// Notifications that simply bring the user back to the app (resume recording).
    static let resumeCategory = "earshot.resume"
    /// Informational notifications without actions.
    static let infoCategory = "earshot.info"
    /// Prompt categories are "prompt:<prompt id>".
    static let promptCategoryPrefix = "prompt:"
    /// Prompt notification request identifiers are "prompt.<prompt id>".
    static let promptRequestPrefix = "prompt."
    /// userInfo key carrying the prompt id.
    static let promptIDKey = "promptID"

    static let choiceActionPrefix = "choice:"
    static let replyAction = "reply"
    static let notNowAction = "notnow"

    static func post(id: String, title: String, body: String, category: String,
                     after delay: TimeInterval? = nil, userInfo: [String: String] = [:]) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        var info: [AnyHashable: Any] = [:]
        for (key, value) in userInfo { info[key] = value }
        content.userInfo = info
        let trigger = delay.map { UNTimeIntervalNotificationTrigger(timeInterval: max(1, $0), repeats: false) }
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                WatchLog.error("Couldn't schedule notification \(id): \(error.localizedDescription)")
            }
        }
    }

    static func cancel(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }
}

// MARK: - Model

/// A prompt as the watch keeps it.
struct InboxPrompt: Codable, Hashable, Identifiable {
    var prompt: WirePrompt
    var receivedAt: Date
    /// First time the prompt reached the user (notification, haptic or Inbox).
    var shownAt: Date?
    /// Whether `shownAt` was reported to the Mac in deliveredPromptIDs.
    var deliveryReported: Bool
    var answeredAt: Date?
    var answerMode: AnswerMode?
    var answerSummary: String?
    /// Resolved on the Mac (answered there, expired) before an answer was given here.
    var closedAt: Date?

    var id: String { prompt.id }
    var isOpen: Bool { answeredAt == nil && closedAt == nil }
    var finishedAt: Date? { answeredAt ?? closedAt }
}

// MARK: - PromptCenter

@MainActor
final class PromptCenter: ObservableObject {
    @Published private(set) var items: [InboxPrompt] = []
    /// A prompt that just arrived while the app was on screen (shown as a banner).
    @Published private(set) var arrival: InboxPrompt? = nil

    private let queue: SegmentQueue
    private let fileURL: URL
    private var clockSkew: TimeInterval = 0
    /// What was last passed to setNotificationCategories (nil until the first registration).
    private var registeredSignature: [String]?
    private var arrivalTask: Task<Void, Never>?

    private static let historyWindow: TimeInterval = 24 * 60 * 60
    private static let maxCategories = 20
    /// A prompt answered here that the Mac still lists after this long is shown again.
    private static let reaskDelay: TimeInterval = 10 * 60
    /// …unless an answer reached the Mac this recently (the list may predate it, or the Mac
    /// may still be working on the answer).
    private static let deliveryGrace: TimeInterval = 5 * 60

    init(queue: SegmentQueue) {
        self.queue = queue
        fileURL = WatchPaths.applicationSupport.appendingPathComponent("prompts.json")
        load()
        prune()
    }

    // MARK: Queries

    /// Waiting for an answer: urgent first, then newest.
    var openPrompts: [InboxPrompt] {
        items.filter(\.isOpen).sorted { a, b in
            if a.prompt.priority != b.prompt.priority { return a.prompt.priority > b.prompt.priority }
            return a.prompt.createdAt > b.prompt.createdAt
        }
    }

    /// Answered or resolved in the last 24 hours, newest first.
    var historyPrompts: [InboxPrompt] {
        items.filter { !$0.isOpen }.sorted { ($0.finishedAt ?? .distantPast) > ($1.finishedAt ?? .distantPast) }
    }

    var unansweredCount: Int { items.filter(\.isOpen).count }

    func item(id: String) -> InboxPrompt? {
        items.first { $0.id == id }
    }

    // MARK: Sync

    /// Applies the prompt list from /sync. New prompts are announced: a haptic and
    /// a banner when the app is on screen, a local notification otherwise.
    func apply(_ incoming: [WirePrompt], serverTime: Date, appActive: Bool) {
        let now = Date()
        clockSkew = serverTime.timeIntervalSince(now)
        let incomingIDs = Set(incoming.map(\.id))
        var fresh: [InboxPrompt] = []

        for wire in incoming {
            if let index = items.firstIndex(where: { $0.id == wire.id }) {
                var item = items[index]
                item.prompt = wire
                let deliveredJustNow = queue.lastAnswerDelivery(for: wire.id)
                    .map { now.timeIntervalSince($0) < PromptCenter.deliveryGrace } ?? false
                if let answeredAt = item.answeredAt,
                   now.timeIntervalSince(answeredAt) > PromptCenter.reaskDelay,
                   !queue.hasPendingAnswer(for: wire.id),
                   !deliveredJustNow {
                    // Answered here, yet the Mac lists only prompts it hasn't settled: it asks
                    // again (after "Later", or a choice or reply it reads as "later"), or it
                    // never took the answer (dropped, or not accepted for this prompt).
                    item.answeredAt = nil
                    item.answerMode = nil
                    item.answerSummary = nil
                    item.shownAt = nil
                    item.deliveryReported = false
                    item.receivedAt = now
                    fresh.append(item)
                } else if item.answeredAt == nil, item.closedAt != nil {
                    // It came back (e.g. a sync glitch hid it); reopen quietly.
                    item.closedAt = nil
                }
                items[index] = item
            } else {
                let item = InboxPrompt(prompt: wire, receivedAt: now, shownAt: nil, deliveryReported: false,
                                       answeredAt: nil, answerMode: nil, answerSummary: nil, closedAt: nil)
                items.append(item)
                fresh.append(item)
            }
        }

        // Open prompts the Mac no longer lists were answered on the Mac or expired.
        var closedIDs: [String] = []
        for index in items.indices where items[index].isOpen && !incomingIDs.contains(items[index].id) {
            items[index].closedAt = now
            closedIDs.append(items[index].id)
        }
        LocalNotifier.cancel(closedIDs.map { LocalNotifier.promptRequestPrefix + $0 })

        prune()
        save()

        guard !fresh.isEmpty else {
            Task { await self.registerCategories() }
            return
        }
        let freshIDs = fresh.map(\.id)
        if appActive {
            markShown(freshIDs)
            let top = fresh.max { $0.prompt.priority < $1.prompt.priority }
            Haptics.prompt(priority: top?.prompt.priority ?? 3)
            if let top { showArrival(top) }
        } else {
            let prompts = fresh.map(\.prompt)
            Task {
                await self.registerCategories()
                let settings = await UNUserNotificationCenter.current().notificationSettings()
                var posted: [String] = []
                for prompt in prompts {
                    if await self.postNotification(for: prompt) { posted.append(prompt.id) }
                }
                // Reported to the Mac as delivered only when the notification can appear;
                // otherwise the prompt counts as shown once the Inbox shows it (the Mac stops
                // listing delivered prompts after a few hours).
                if settings.authorizationStatus == .authorized { self.markShown(posted) }
            }
        }
    }

    /// Prompts shown since the last successful sync.
    func deliveredIDsToReport() -> [String] {
        items.filter { $0.shownAt != nil && !$0.deliveryReported }.map(\.id)
    }

    func confirmReported(_ ids: [String]) {
        guard !ids.isEmpty else { return }
        let reported = Set(ids)
        var changed = false
        for index in items.indices where reported.contains(items[index].id) && !items[index].deliveryReported {
            items[index].deliveryReported = true
            changed = true
        }
        if changed { save() }
    }

    func markShown(_ ids: [String]) {
        let wanted = Set(ids)
        let now = Date()
        var changed = false
        for index in items.indices where wanted.contains(items[index].id) && items[index].shownAt == nil {
            items[index].shownAt = now
            changed = true
        }
        if changed { save() }
    }

    /// Closes prompts past their expiry date (Mac clock) and drops old history.
    func refreshExpiry() {
        let macNow = Date().addingTimeInterval(clockSkew)
        var expired: [String] = []
        for index in items.indices where items[index].isOpen {
            if let expiresAt = items[index].prompt.expiresAt, expiresAt < macNow {
                items[index].closedAt = Date()
                expired.append(items[index].id)
            }
        }
        let before = items.count
        prune()
        guard !expired.isEmpty || items.count != before else { return }
        LocalNotifier.cancel(expired.map { LocalNotifier.promptRequestPrefix + $0 })
        save()
        Task { await self.registerCategories() }
    }

    func clearAll() {
        let ids = items.map { LocalNotifier.promptRequestPrefix + $0.id }
        items = []
        arrival = nil
        save()
        LocalNotifier.cancel(ids)
        Task { await self.registerCategories() }
    }

    // MARK: Answers

    /// Records an answer locally and queues it for the Mac.
    func answer(_ promptID: String, mode: AnswerMode, choiceID: String? = nil, text: String? = nil,
                answeredAt: Date = Date(), voiceWindowSeconds: Double? = nil) {
        let answer = PromptAnswer(promptID: promptID, mode: mode, choiceID: choiceID, text: text,
                                  answeredAt: answeredAt, voiceWindowSeconds: voiceWindowSeconds)
        queue.enqueue(.answer(answer))
        if let index = items.firstIndex(where: { $0.id == promptID }) {
            let now = Date()
            items[index].answeredAt = now
            items[index].answerMode = mode
            items[index].answerSummary = summary(for: items[index].prompt, mode: mode, choiceID: choiceID, text: text)
            if items[index].shownAt == nil { items[index].shownAt = now }
            save()
        }
        if arrival?.id == promptID { arrival = nil }
        LocalNotifier.cancel([LocalNotifier.promptRequestPrefix + promptID])
        Task { await self.registerCategories() }
        WatchLog.info("Answered prompt \(promptID) (\(mode.rawValue))")
    }

    /// Maps a notification action to an answer. Returns the prompt id when the app
    /// should open that prompt instead (plain tap, or an empty reply).
    func handleNotificationResponse(promptID: String, actionIdentifier: String, userText: String?) -> String? {
        if actionIdentifier.hasPrefix(LocalNotifier.choiceActionPrefix) {
            let choiceID = String(actionIdentifier.dropFirst(LocalNotifier.choiceActionPrefix.count))
            answer(promptID, mode: .choice, choiceID: choiceID)
            return nil
        }
        switch actionIdentifier {
        case LocalNotifier.replyAction:
            let text = (userText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                markShown([promptID])
                return promptID
            }
            answer(promptID, mode: .text, text: text)
            return nil
        case LocalNotifier.notNowAction:
            if item(id: promptID)?.prompt.kind == .approval {
                // On the Mac a dismissal denies an approval; leave it pending instead.
                markShown([promptID])
                return nil
            }
            answer(promptID, mode: .dismissed)
            return nil
        case UNNotificationDismissActionIdentifier:
            // Delivered only for categories with .customDismissAction (none today); kept so an
            // explicit dismissal never opens the prompt.
            markShown([promptID])
            return nil
        default:
            markShown([promptID])
            return promptID
        }
    }

    func dismissArrival() {
        arrivalTask?.cancel()
        arrival = nil
    }

    // MARK: Notifications

    /// Registers one category per open prompt (latest 20) plus the fixed ones.
    /// `setNotificationCategories` replaces the whole set.
    func registerCategories() async {
        let latest = items.filter(\.isOpen)
            .sorted { $0.prompt.createdAt > $1.prompt.createdAt }
            .prefix(PromptCenter.maxCategories)
        let signature: [String] = latest.map { item in
            let choiceIDs = item.prompt.choices.map { $0.id }.joined(separator: ",")
            return item.id + "|" + choiceIDs + "|" + (item.prompt.allowsFreeText ? "text" : "")
        }
        guard signature != registeredSignature else { return }
        registeredSignature = signature

        var categories = Set<UNNotificationCategory>()
        categories.insert(UNNotificationCategory(identifier: LocalNotifier.resumeCategory, actions: [],
                                                 intentIdentifiers: [], options: []))
        categories.insert(UNNotificationCategory(identifier: LocalNotifier.infoCategory, actions: [],
                                                 intentIdentifiers: [], options: []))
        for item in latest {
            categories.insert(PromptCenter.category(for: item.prompt))
        }
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories(categories)
        // Reading the set back makes sure it is registered before a notification uses it.
        _ = await center.notificationCategories()
    }

    /// Returns true when the notification was scheduled.
    private func postNotification(for prompt: WirePrompt) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = prompt.title.isEmpty ? PromptStyle.label(prompt.kind) : prompt.title
        content.body = prompt.body
        content.sound = .default
        content.categoryIdentifier = LocalNotifier.promptCategoryPrefix + prompt.id
        content.threadIdentifier = "earshot.prompts"
        content.userInfo = [LocalNotifier.promptIDKey: prompt.id]
        content.interruptionLevel = prompt.priority <= 1 ? .passive : .active
        let request = UNNotificationRequest(identifier: LocalNotifier.promptRequestPrefix + prompt.id,
                                            content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            WatchLog.error("Couldn't show prompt \(prompt.id): \(error.localizedDescription)")
            return false
        }
    }

    private static func category(for prompt: WirePrompt) -> UNNotificationCategory {
        var actions: [UNNotificationAction] = []
        for choice in prompt.choices.prefix(3) {
            let options: UNNotificationActionOptions = choice.id == "deny" ? [.destructive] : []
            actions.append(UNNotificationAction(identifier: LocalNotifier.choiceActionPrefix + choice.id,
                                                title: choice.title, options: options))
        }
        if prompt.allowsFreeText {
            actions.append(UNTextInputNotificationAction(identifier: LocalNotifier.replyAction, title: "Reply…",
                                                         options: [], textInputButtonTitle: "Send",
                                                         textInputPlaceholder: "Your answer"))
        }
        if prompt.kind != .approval {
            // For an approval the Mac reads "Not now" as Deny; Approve and Deny are there, and
            // leaving the notification alone keeps the request pending.
            actions.append(UNNotificationAction(identifier: LocalNotifier.notNowAction, title: "Not now", options: []))
        }
        return UNNotificationCategory(identifier: LocalNotifier.promptCategoryPrefix + prompt.id,
                                      actions: actions, intentIdentifiers: [], options: [])
    }

    private func showArrival(_ item: InboxPrompt) {
        arrival = item
        arrivalTask?.cancel()
        arrivalTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.arrival = nil
        }
    }

    private func summary(for prompt: WirePrompt, mode: AnswerMode, choiceID: String?, text: String?) -> String {
        switch mode {
        case .choice:
            return prompt.choices.first(where: { $0.id == choiceID })?.title ?? (choiceID ?? "Answered")
        case .text:
            return text ?? "Replied"
        case .voiceWindow:
            return "Spoken answer"
        case .dismissed:
            return "Not now"
        case .snoozed:
            return "Later"
        }
    }

    // MARK: Persistence

    private func prune() {
        let cutoff = Date().addingTimeInterval(-PromptCenter.historyWindow)
        items.removeAll { item in
            guard let finished = item.finishedAt else { return false }
            return finished < cutoff
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            items = try EarshotAPI.makeDecoder().decode([InboxPrompt].self, from: data)
        } catch {
            WatchLog.error("Prompt history unreadable, starting empty: \(error.localizedDescription)")
            items = []
        }
    }

    private func save() {
        do {
            let data = try EarshotAPI.makeEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            WatchLog.error("Couldn't save prompts: \(error.localizedDescription)")
        }
    }
}
