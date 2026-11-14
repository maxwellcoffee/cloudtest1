//  EarshotWatchApp.swift
//  Earshot (watchOS)
//
//  Entry point of the standalone watch app.

import SwiftUI
import WatchKit

@main
struct EarshotWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @StateObject private var store = WatchStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(store.recorder)
                .environmentObject(store.queue)
                .environmentObject(store.prompts)
                .tint(.red)
        }
    }
}
