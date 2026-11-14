//  TodayBuilder.swift
//  The small "today" card shown on the watch and in the Mac menu bar.

import Foundation

enum TodayBuilder {
    private static let summaryKey = "insights.lastSummary"
    private static let summaryAtKey = "insights.lastSummaryAt"
    private static let listening = "Listening…"

    static func snapshot(db: Database) -> TodaySnapshot {
        let now = Date()
        let start = now.startOfDay
        let end = now.endOfDay

        let words = db.wordCount(from: start, to: now)
        let seconds = db.recordedSeconds(from: start, to: end)
        let minutes = seconds.isFinite ? (max(0, seconds) / 60 * 10).rounded() / 10 : 0

        let openLoops = db.insights(statuses: [.open], kinds: [.task, .commitment], since: nil, limit: 1_000)
        let highlights = db.insights(statuses: [.open, .done], kinds: [.highlight, .decision, .commitment],
                                     since: start, limit: 20)
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
            .map { $0.title.clipped(60) }

        return TodaySnapshot(headline: headline(db: db, now: now),
                             wordsToday: words,
                             minutesRecorded: minutes,
                             openTasks: openLoops.count,
                             highlights: Array(highlights),
                             nextUp: nextUp(now: now, openLoops: openLoops))
    }

    /// First sentence of today's digest, else the latest analysis summary from today, else "Listening…".
    private static func headline(db: Database, now: Date) -> String {
        if let digest = db.digest(day: now.dayKey) {
            let brief = PromptLibrary.digestBrief(digest.markdown, sentences: 1)
            if !brief.isEmpty { return brief.clipped(160) }
        }
        if let summary = db.kvGet(summaryKey)?.nilIfEmpty {
            var fresh = true
            if let stamp = Double(db.kvGet(summaryAtKey) ?? ""), stamp.isFinite {
                fresh = Calendar.current.isDate(Date(timeIntervalSince1970: stamp), inSameDayAs: now)
            }
            if fresh { return PromptLibrary.firstSentences(summary, count: 1).clipped(160) }
        }
        return listening
    }

    /// "3:00 PM Design review" for the next event within 12 hours, else the earliest-due open task.
    private static func nextUp(now: Date, openLoops: [Insight]) -> String? {
        let calendar = Calendar.current
        let events = CalendarService.shared.upcomingEvents(hours: 12)
            .filter { $0.start >= now && $0.end.timeIntervalSince($0.start) < 23 * 3_600 }
            .sorted { $0.start < $1.start }
        if let event = events.first {
            let prefix = calendar.isDate(event.start, inSameDayAs: now) ? "" : "Tomorrow "
            return "\(prefix)\(event.start.timeText) \(event.title)".clipped(80)
        }

        let dated = openLoops.filter { $0.dueAt != nil }
            .sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        guard let task = dated.first, let due = task.dueAt else { return nil }
        let components = calendar.dateComponents([.hour, .minute], from: due)
        let hasTime = (components.hour ?? 0) != 0 || (components.minute ?? 0) != 0
        let when: String
        if calendar.isDate(due, inSameDayAs: now) {
            when = due < now && hasTime ? "Overdue" : (hasTime ? "Due \(due.timeText)" : "Due today")
        } else if due < now {
            when = "Overdue"
        } else if calendar.isDateInTomorrow(due) {
            when = hasTime ? "Due tomorrow \(due.timeText)" : "Due tomorrow"
        } else {
            when = "Due \(PromptLibrary.formatted(due, template: "EEE MMM d"))"
        }
        return "\(when): \(task.title)".clipped(80)
    }
}
