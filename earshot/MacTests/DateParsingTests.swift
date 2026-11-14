//  DateParsingTests.swift
//  Every format listed in DateParsing.parse's documentation.

import XCTest
@testable import Earshot

final class DateParsingTests: XCTestCase {

    /// 2026-11-14T15:00:00Z
    private let utcThreePM: TimeInterval = 1_794_668_400

    private func assertLocal(_ raw: String,
                             year: Int, month: Int, day: Int,
                             hour: Int, minute: Int, second: Int = 0,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let date = DateParsing.parse(raw) else {
            XCTFail("Could not parse \"\(raw)\"", file: file, line: line)
            return
        }
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        XCTAssertEqual(c.year, year, "year of \(raw)", file: file, line: line)
        XCTAssertEqual(c.month, month, "month of \(raw)", file: file, line: line)
        XCTAssertEqual(c.day, day, "day of \(raw)", file: file, line: line)
        XCTAssertEqual(c.hour, hour, "hour of \(raw)", file: file, line: line)
        XCTAssertEqual(c.minute, minute, "minute of \(raw)", file: file, line: line)
        XCTAssertEqual(c.second, second, "second of \(raw)", file: file, line: line)
    }

    func testInternetDateTimeWithOffset() throws {
        let date = try XCTUnwrap(DateParsing.parse("2026-11-14T15:00:00-08:00"))
        XCTAssertEqual(date.timeIntervalSince1970, utcThreePM + 8 * 3600, accuracy: 0.001)
    }

    func testInternetDateTimeInUTC() throws {
        let date = try XCTUnwrap(DateParsing.parse("2026-11-14T15:00:00Z"))
        XCTAssertEqual(date.timeIntervalSince1970, utcThreePM, accuracy: 0.001)
    }

    func testFractionalSeconds() throws {
        let date = try XCTUnwrap(DateParsing.parse("2026-11-14T15:00:00.123Z"))
        XCTAssertEqual(date.timeIntervalSince1970, utcThreePM + 0.123, accuracy: 0.001)
    }

    func testLocalDateTimeWithSeconds() {
        assertLocal("2026-11-14T15:00:00", year: 2026, month: 11, day: 14, hour: 15, minute: 0)
        assertLocal("2026-11-14T09:05:30", year: 2026, month: 11, day: 14, hour: 9, minute: 5, second: 30)
    }

    func testLocalDateTimeWithoutSeconds() {
        assertLocal("2026-11-14T15:00", year: 2026, month: 11, day: 14, hour: 15, minute: 0)
    }

    func testLocalDateTimeWithSpace() {
        assertLocal("2026-11-14 15:00", year: 2026, month: 11, day: 14, hour: 15, minute: 0)
        assertLocal("2026-11-14 15:00:45", year: 2026, month: 11, day: 14, hour: 15, minute: 0, second: 45)
    }

    func testDateOnlyIsLocalMidnight() {
        assertLocal("2026-11-14", year: 2026, month: 11, day: 14, hour: 0, minute: 0)
    }

    func testSurroundingWhitespaceIsIgnored() throws {
        let date = try XCTUnwrap(DateParsing.parse("  2026-11-14T15:00:00Z \n"))
        XCTAssertEqual(date.timeIntervalSince1970, utcThreePM, accuracy: 0.001)
        assertLocal(" 2026-11-14 ", year: 2026, month: 11, day: 14, hour: 0, minute: 0)
    }

    func testRejectsMissingAndUnparseableInput() {
        XCTAssertNil(DateParsing.parse(nil))
        XCTAssertNil(DateParsing.parse(""))
        XCTAssertNil(DateParsing.parse("   "))
        XCTAssertNil(DateParsing.parse("tomorrow at 3"))
        XCTAssertNil(DateParsing.parse("14/11/2026"))
    }

    func testIsDateOnly() {
        XCTAssertTrue(DateParsing.isDateOnly("2026-11-14"))
        XCTAssertTrue(DateParsing.isDateOnly(" 2026-11-14 "))
        XCTAssertFalse(DateParsing.isDateOnly("2026-11-14T15:00"))
        XCTAssertFalse(DateParsing.isDateOnly("2026-11-14 15:00"))
        XCTAssertFalse(DateParsing.isDateOnly(""))
        XCTAssertFalse(DateParsing.isDateOnly(nil))
    }

    func testIsoLocalRoundTrips() throws {
        let date = Date(timeIntervalSince1970: utcThreePM)
        let text = DateParsing.isoLocal(date)
        XCTAssertFalse(text.contains("."), "whole seconds only: \(text)")
        let parsed = try XCTUnwrap(DateParsing.parse(text))
        XCTAssertEqual(parsed.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testDayKeyAndDayBounds() throws {
        let date = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 15, minute: 30)))
        XCTAssertEqual(date.dayKey, "2026-11-14")
        XCTAssertEqual(date.startOfDay.dayKey, "2026-11-14")
        XCTAssertEqual(date.endOfDay.dayKey, "2026-11-15")
        XCTAssertEqual(date.endOfDay, Calendar.current.startOfDay(for: date.endOfDay))
        XCTAssertLessThan(date.startOfDay, date)
        XCTAssertGreaterThan(date.endOfDay, date)
    }
}
