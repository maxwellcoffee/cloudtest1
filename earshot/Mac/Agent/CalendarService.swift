//  CalendarService.swift
//  Calendar and Reminders access through EventKit (macOS 14 full-access APIs).
//
//  EKEventStore can be used from any thread. The only mutable state here is the
//  store reference itself, which is replaced after access is granted so newly
//  authorised sources show up; it is guarded by a lock.

import Foundation
import EventKit

struct CalendarEventSummary: Hashable, Sendable {
    var title: String
    var start: Date
    var end: Date
    var location: String?
}

private enum CalendarServiceError: LocalizedError {
    case noEventAccess
    case noReminderAccess
    case noDefaultCalendar
    case noDefaultReminderList
    case emptyTitle

    var errorDescription: String? {
        switch self {
        case .noEventAccess:
            return "Earshot doesn't have access to your calendars. Allow it in System Settings → Privacy & Security → Calendars."
        case .noReminderAccess:
            return "Earshot doesn't have access to Reminders. Allow it in System Settings → Privacy & Security → Reminders."
        case .noDefaultCalendar:
            return "There is no default calendar for new events. Choose one in Calendar → Settings → General."
        case .noDefaultReminderList:
            return "There is no default list for new reminders. Choose one in Reminders → Settings."
        case .emptyTitle:
            return "A title is required."
        }
    }
}

final class CalendarService: @unchecked Sendable {
    static let shared = CalendarService()

    private let lock = NSLock()
    private var eventStore = EKEventStore()

    /// Longest range queried at once (EventKit rejects predicates spanning more than ~4 years).
    private static let maxQueryHours: Double = 24 * 366

    private var store: EKEventStore {
        lock.lock()
        defer { lock.unlock() }
        return eventStore
    }

    // MARK: Access

    var hasEventAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    var hasReminderAccess: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    /// Requests full access to events and reminders. Returns true when both are granted.
    func requestAccess() async -> Bool {
        let current = store
        var events = hasEventAccess
        var reminders = hasReminderAccess
        var changed = false

        if !events {
            do {
                events = try await current.requestFullAccessToEvents()
                changed = changed || events
            } catch {
                Log.error("CalendarService: calendar access request failed: \(error.localizedDescription)")
                events = false
            }
        }
        if !reminders {
            do {
                reminders = try await current.requestFullAccessToReminders()
                changed = changed || reminders
            } catch {
                Log.error("CalendarService: reminders access request failed: \(error.localizedDescription)")
                reminders = false
            }
        }

        if changed {
            // A store created before authorisation may not see the newly available sources.
            let fresh = EKEventStore()
            lock.lock()
            eventStore = fresh
            lock.unlock()
        }
        Log.info("CalendarService: access calendars=\(events) reminders=\(reminders)")
        return events && reminders
    }

    // MARK: Queries

    /// True when a timed (not all-day), non-free, non-cancelled event overlaps `date`.
    func isBusy(at date: Date) -> Bool {
        guard hasEventAccess else { return false }
        let s = store
        let predicate = s.predicateForEvents(withStart: date.addingTimeInterval(-60),
                                             end: date.addingTimeInterval(60),
                                             calendars: nil)
        return s.events(matching: predicate).contains { event in
            guard !event.isAllDay,
                  event.availability != .free,
                  event.status != .canceled,
                  let start = event.startDate,
                  let end = event.endDate else { return false }
            return start <= date && end > date
        }
    }

    /// Events overlapping now ... now + hours (including ones already in progress), sorted by start.
    func upcomingEvents(hours: Double) -> [CalendarEventSummary] {
        guard hasEventAccess else { return [] }
        let span = hours.isFinite ? min(max(hours, 0), CalendarService.maxQueryHours) : 24
        guard span > 0 else { return [] }
        let now = Date()
        return summaries(from: now, to: now.addingTimeInterval(span * 3_600))
    }

    /// Events overlapping the local calendar day containing `day`, sorted by start.
    func events(on day: Date) -> [CalendarEventSummary] {
        guard hasEventAccess else { return [] }
        return summaries(from: day.startOfDay, to: day.endOfDay)
    }

    private func summaries(from start: Date, to end: Date) -> [CalendarEventSummary] {
        guard end > start else { return [] }
        let s = store
        let predicate = s.predicateForEvents(withStart: start, end: end, calendars: nil)
        return s.events(matching: predicate)
            .compactMap { event -> CalendarEventSummary? in
                guard event.status != .canceled,
                      let eventStart = event.startDate,
                      let eventEnd = event.endDate else { return nil }
                let title = (event.title ?? "").trimmed
                return CalendarEventSummary(title: title.isEmpty ? "(No title)" : title,
                                            start: eventStart,
                                            end: eventEnd,
                                            location: event.location?.nilIfEmpty)
            }
            .sorted { lhs, rhs in
                lhs.start == rhs.start ? lhs.title < rhs.title : lhs.start < rhs.start
            }
    }

    // MARK: Creation

    /// Creates a reminder in the default list. With a timed due date an alarm fires at that time.
    /// Returns the reminder's calendar item identifier.
    func createReminder(title: String, notes: String?, due: Date?, dateOnly: Bool) throws -> String {
        guard hasReminderAccess else { throw CalendarServiceError.noReminderAccess }
        let cleanTitle = title.trimmed
        guard !cleanTitle.isEmpty else { throw CalendarServiceError.emptyTitle }
        let s = store
        guard let list = s.defaultCalendarForNewReminders() else { throw CalendarServiceError.noDefaultReminderList }

        let reminder = EKReminder(eventStore: s)
        reminder.title = cleanTitle
        reminder.notes = notes?.nilIfEmpty
        reminder.calendar = list

        if let due {
            let calendar = Calendar.current
            if dateOnly {
                var components = calendar.dateComponents([.year, .month, .day], from: due)
                components.calendar = calendar
                reminder.dueDateComponents = components
            } else {
                var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: due)
                components.calendar = calendar
                components.timeZone = TimeZone.current
                reminder.dueDateComponents = components
                reminder.addAlarm(EKAlarm(absoluteDate: due))
            }
        }

        try s.save(reminder, commit: true)
        Log.info("CalendarService: created reminder \"\(cleanTitle.clipped(60))\" in \(list.title)")
        return reminder.calendarItemIdentifier
    }

    /// Creates an event in the default calendar. For all-day events `end` is the last day (inclusive).
    /// Returns the event identifier.
    func createEvent(title: String, start: Date, end: Date, location: String?, notes: String?, allDay: Bool) throws -> String {
        guard hasEventAccess else { throw CalendarServiceError.noEventAccess }
        let cleanTitle = title.trimmed
        guard !cleanTitle.isEmpty else { throw CalendarServiceError.emptyTitle }
        let s = store
        guard let calendar = s.defaultCalendarForNewEvents else { throw CalendarServiceError.noDefaultCalendar }

        let event = EKEvent(eventStore: s)
        event.title = cleanTitle
        event.location = location?.nilIfEmpty
        event.notes = notes?.nilIfEmpty
        event.calendar = calendar
        event.isAllDay = allDay
        if allDay {
            let firstDay = start.startOfDay
            let lastDay = max(end, start).startOfDay
            event.startDate = firstDay
            event.endDate = lastDay
        } else {
            event.startDate = start
            event.endDate = end > start ? end : start.addingTimeInterval(30 * 60)
        }

        try s.save(event, span: .thisEvent, commit: true)
        Log.info("CalendarService: created event \"\(cleanTitle.clipped(60))\" in \(calendar.title)")
        return event.eventIdentifier ?? event.calendarItemIdentifier
    }
}
