//  WatchAppDelegate.swift
//  Earshot (watchOS)
//
//  App-level events: launch, background refresh, and notification responses.

import Foundation
import UserNotifications
import WatchKit

@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    private static let refreshInterval: TimeInterval = 15 * 60
    /// watchOS gives a refresh task only a few seconds; the work is limited to messages and /sync.
    private static let refreshBudget: TimeInterval = 10

    /// UNUserNotificationCenter keeps its delegate weakly; the app delegate owns it.
    private let notificationDelegate = NotificationDelegate()

    // MARK: WKApplicationDelegate

    func applicationDidFinishLaunching() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        let store = WatchStore.shared
        store.requestNotificationAuthorization()
        Task { await store.prompts.registerCategories() }
        scheduleNextRefresh()
        WatchLog.info("Launched (\(store.appVersion))")
    }

    func applicationDidEnterBackground() {
        scheduleNextRefresh()
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            if let refresh = task as? WKApplicationRefreshBackgroundTask {
                runRefresh(refresh)
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }

    /// Delivers messages and syncs within a short budget, then completes the task. If the
    /// system runs out of time first, the task is completed right away (an overrunning
    /// task gets the app terminated).
    private func runRefresh(_ task: WKApplicationRefreshBackgroundTask) {
        let store = WatchStore.shared
        let budget = WatchAppDelegate.refreshBudget
        let deadline = Date().addingTimeInterval(budget)
        let completion = BackgroundTaskCompletion(task)
        task.expirationHandler = { @Sendable in
            WatchLog.info("Background refresh ran out of time")
            completion.complete()
        }
        scheduleNextRefresh()
        Task { @MainActor in
            await store.awaitAtMost(budget) {
                await store.performBackgroundRefresh(deadline: deadline)
            }
            completion.complete()
        }
    }

    private func scheduleNextRefresh() {
        let date = Date().addingTimeInterval(WatchAppDelegate.refreshInterval)
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: date, userInfo: nil) { error in
            if let error {
                WatchLog.error("Couldn't schedule a background refresh: \(error.localizedDescription)")
            }
        }
    }
}

/// Completes a background task exactly once: when the work is done or when its time runs
/// out, whichever comes first (the expiration handler may be called on another thread).
private final class BackgroundTaskCompletion: @unchecked Sendable {
    private let task: WKRefreshBackgroundTask
    private let lock = NSLock()
    private var completed = false

    init(_ task: WKRefreshBackgroundTask) {
        self.task = task
    }

    func complete() {
        lock.lock()
        let first = !completed
        completed = true
        lock.unlock()
        if first { task.setTaskCompletedWithSnapshot(false) }
    }
}

/// Notification presentation and responses. Deliberately not actor-isolated:
/// the system may call it on any thread; work hops to the main actor.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        let actionIdentifier = response.actionIdentifier
        let promptID = response.notification.request.content.userInfo[LocalNotifier.promptIDKey] as? String
        let userText = (response as? UNTextInputNotificationResponse)?.userText
        Task { @MainActor in
            let store = WatchStore.shared
            store.handleNotificationResponse(promptID: promptID, actionIdentifier: actionIdentifier,
                                             userText: userText)
            if promptID != nil {
                // An answer given from the notification: try to deliver it before the
                // system suspends the app again. It stays in the outbox otherwise.
                await store.flushOutboxQuickly(seconds: 8)
            }
            completionHandler()
        }
    }
}
