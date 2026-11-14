//  Support.swift
//  Small shared utilities: logging, change events, date parsing/formatting.

import Foundation
import os

// MARK: - Logging

enum Log {
    private static let logger = Logger(subsystem: "com.example.earshot.mac", category: "app")

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }
}

// MARK: - Change events

/// Data domains that changed. Services post these after writing to the
/// database; `AppModel` observes them and reloads the matching published state.
enum DataScope: String, CaseIterable, Sendable {
    case segments, utterances, insights, prompts, actions, goals, digests, devices, chat, agent, status
}

enum EarshotEvents {
    static let changed = Notification.Name("EarshotDataChanged")
    static let scopeKey = "scope"

    /// Safe to call from any thread; delivery happens on the main queue.
    static func post(_ scope: DataScope) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: changed, object: nil, userInfo: [scopeKey: scope.rawValue])
        }
    }

    static func scope(of note: Notification) -> DataScope? {
        guard let raw = note.userInfo?[scopeKey] as? String else { return nil }
        return DataScope(rawValue: raw)
    }
}

// MARK: - Dates

enum DateParsing {
    /// Parses ISO-8601 strings the model may produce:
    /// "2026-11-14T15:00:00-08:00", "2026-11-14T15:00:00Z", "2026-11-14T15:00:00.123Z",
    /// "2026-11-14T15:00" (local), "2026-11-14 15:00" (local), "2026-11-14" (local midnight).
    static func parse(_ raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        let local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = TimeZone.current
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd"] {
            local.dateFormat = format
            if let d = local.date(from: raw) { return d }
        }
        return nil
    }

    /// True if the string has no time component (all-day).
    static func isDateOnly(_ raw: String?) -> Bool {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return raw.count == 10 && raw.contains("-") && !raw.contains("T")
    }

    /// "2026-11-14T15:04:05-08:00" in the current time zone (for prompts to the model).
    static func isoLocal(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }
}

extension Date {
    /// "yyyy-MM-dd" in the local time zone.
    var dayKey: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }

    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? self.addingTimeInterval(86_400)
    }

    /// "3:42 PM"
    var timeText: String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: self)
    }

    /// "Sat, Nov 14, 3:42 PM"
    var shortText: String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEE MMM d h:mm a")
        return f.string(from: self)
    }

    /// "5 min ago"
    var relativeText: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: self, relativeTo: Date())
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Truncates to at most `max` characters, appending "…" when cut.
    func clipped(_ max: Int) -> String {
        count <= max ? self : String(prefix(max)) + "…"
    }

    var nilIfEmpty: String? {
        let t = trimmed
        return t.isEmpty ? nil : t
    }
}

// MARK: - Paths

enum AppPaths {
    /// ~/Library/Application Support/Earshot
    static var supportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("Earshot", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Audio segments: .../Earshot/Audio/yyyy-MM-dd/<id>.m4a
    static func audioDirectory(for day: Date) -> URL {
        let dir = supportDirectory.appendingPathComponent("Audio", isDirectory: true)
            .appendingPathComponent(day.dayKey, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var databaseURL: URL { supportDirectory.appendingPathComponent("earshot.sqlite") }

    static var temporaryDirectory: URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Earshot", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
