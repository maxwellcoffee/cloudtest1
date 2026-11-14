//  Haptics.swift
//  Earshot (watchOS)
//
//  The app's small haptic vocabulary, plus the shared logger.

import Foundation
import WatchKit
import os

/// Haptic feedback used across the watch app. All calls happen on the main actor.
@MainActor
enum Haptics {
    static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    /// A bookmark was placed, an answer was sent, pairing worked.
    static func success() { play(.success) }

    /// Something the user asked for did not happen.
    static func failure() { play(.failure) }

    /// Recording stopped unexpectedly or needs attention.
    static func warning() { play(.retry) }

    /// Light acknowledgement of a tap.
    static func click() { play(.click) }

    /// The microphone started.
    static func start() { play(.start) }

    /// The microphone stopped or paused.
    static func stop() { play(.stop) }

    /// A new prompt arrived while the app is on screen. Strength follows the
    /// prompt's priority (1 low … 5 urgent).
    static func prompt(priority: Int) {
        switch priority {
        case 4...:
            play(.notification)
        case 3:
            play(.directionUp)
        default:
            play(.click)
        }
    }
}

/// Unified logging for the watch app (visible in Console.app when the watch is attached).
enum WatchLog {
    private static let logger = Logger(subsystem: "com.earshot.watch", category: "app")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
