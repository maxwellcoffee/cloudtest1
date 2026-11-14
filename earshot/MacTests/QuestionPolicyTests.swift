//  QuestionPolicyTests.swift
//  When the companion may release a proactive question to the watch.

import XCTest
@testable import Earshot

final class QuestionPolicyTests: XCTestCase {

    /// A local time on a day without daylight-saving transitions.
    private func localTime(_ hour: Int, _ minute: Int = 0) throws -> Date {
        try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15,
                                                                  hour: hour, minute: minute)))
    }

    /// Settings with the documented defaults spelled out, so the tests do not
    /// depend on future default changes.
    private func settings() -> AppSettings {
        var s = AppSettings()
        s.questionsEnabled = true
        s.maxQuestionsPerDay = 6
        s.minMinutesBetweenQuestions = 75
        s.quietHoursStart = 21
        s.quietHoursEnd = 8
        s.avoidQuestionsDuringConversation = true
        s.avoidQuestionsDuringMeetings = true
        return s
    }

    private func check(_ now: Date, _ settings: AppSettings, releasedToday: Int = 0, lastRelease: Date? = nil,
                       words: Int = 0, busy: Bool = false) -> (allowed: Bool, reason: String) {
        QuestionPolicy.canRelease(now: now, settings: settings, releasedToday: releasedToday,
                                  lastRelease: lastRelease, wordsLastFiveMinutes: words, calendarBusy: busy)
    }

    private func assertDenied(_ result: (allowed: Bool, reason: String), _ message: String,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(result.allowed, message, file: file, line: line)
        XCTAssertFalse(result.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                       "a denial explains itself (\(message))", file: file, line: line)
    }

    func testAllowedOnAQuietMiddayWithNothingReleased() throws {
        let result = check(try localTime(12), settings())
        XCTAssertTrue(result.allowed, result.reason)
    }

    func testQuestionsDisabled() throws {
        var s = settings()
        s.questionsEnabled = false
        assertDenied(check(try localTime(12), s), "questions are turned off")
    }

    // MARK: Quiet hours

    func testQuietHoursBlockLateEveningAndEarlyMorning() throws {
        assertDenied(check(try localTime(22, 30), settings()), "22:30 is inside 21-8 quiet hours")
        assertDenied(check(try localTime(2), settings()), "02:00 is inside 21-8 quiet hours")
        assertDenied(check(try localTime(7, 45), settings()), "07:45 is inside 21-8 quiet hours")
        XCTAssertTrue(check(try localTime(8, 15), settings()).allowed, "08:15 is after quiet hours")
        XCTAssertTrue(check(try localTime(20, 30), settings()).allowed, "20:30 is before quiet hours")
    }

    func testCustomDaytimeQuietHours() throws {
        var s = settings()
        s.quietHoursStart = 13
        s.quietHoursEnd = 14
        assertDenied(check(try localTime(13, 30), s), "13:30 is inside 13-14 quiet hours")
        XCTAssertTrue(check(try localTime(12), s).allowed)
        XCTAssertTrue(check(try localTime(14, 30), s).allowed)
    }

    // MARK: Daily cap

    func testDailyCap() throws {
        let now = try localTime(12)
        XCTAssertTrue(check(now, settings(), releasedToday: 5).allowed, "5 of 6 released")
        assertDenied(check(now, settings(), releasedToday: 6), "6 of 6 released")
        assertDenied(check(now, settings(), releasedToday: 9), "over the cap")

        var s = settings()
        s.maxQuestionsPerDay = 2
        assertDenied(check(now, s, releasedToday: 2), "2 of 2 released")
        XCTAssertTrue(check(now, s, releasedToday: 1).allowed, "1 of 2 released")
    }

    // MARK: Minimum gap

    func testMinimumGapBetweenQuestions() throws {
        let now = try localTime(15)
        assertDenied(check(now, settings(), releasedToday: 1, lastRelease: now.addingTimeInterval(-30 * 60)),
                     "30 min since the last question, 75 required")
        assertDenied(check(now, settings(), releasedToday: 1, lastRelease: now.addingTimeInterval(-74 * 60)),
                     "74 min since the last question, 75 required")
        XCTAssertTrue(check(now, settings(), releasedToday: 1, lastRelease: now.addingTimeInterval(-76 * 60)).allowed,
                      "76 min since the last question")
        XCTAssertTrue(check(now, settings(), releasedToday: 1, lastRelease: now.addingTimeInterval(-5 * 3600)).allowed,
                      "5 h since the last question")
    }

    // MARK: Conversation and meetings

    func testAvoidsInterruptingAConversation() throws {
        let now = try localTime(11)
        assertDenied(check(now, settings(), words: 1_000), "1000 words in the last five minutes is a conversation")

        var s = settings()
        s.avoidQuestionsDuringConversation = false
        XCTAssertTrue(check(now, s, words: 1_000).allowed, "conversation check disabled")
    }

    func testAvoidsMeetings() throws {
        let now = try localTime(10)
        assertDenied(check(now, settings(), busy: true), "calendar says busy")

        var s = settings()
        s.avoidQuestionsDuringMeetings = false
        XCTAssertTrue(check(now, s, busy: true).allowed, "meeting check disabled")
    }

    func testEveryRuleMustPass() throws {
        let now = try localTime(12)
        let result = check(now, settings(), releasedToday: 1, lastRelease: now.addingTimeInterval(-2 * 3600),
                           words: 0, busy: false)
        XCTAssertTrue(result.allowed, result.reason)
        assertDenied(check(now, settings(), releasedToday: 1, lastRelease: now.addingTimeInterval(-2 * 3600),
                           words: 1_000, busy: true), "conversation and meeting together")
    }
}
