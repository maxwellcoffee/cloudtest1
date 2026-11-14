//  SettingsTests.swift
//  AppSettings: quiet hours and tolerant decoding of stored preferences.

import XCTest
@testable import Earshot

final class SettingsTests: XCTestCase {

    /// A local time on a day without daylight-saving transitions.
    private func localTime(_ hour: Int, _ minute: Int = 0) throws -> Date {
        try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15,
                                                                  hour: hour, minute: minute)))
    }

    private func decode(_ json: String) throws -> AppSettings {
        try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    }

    // MARK: Quiet hours

    func testDefaultQuietHoursRunOvernight() {
        let settings = AppSettings()
        XCTAssertEqual(settings.quietHoursStart, 21)
        XCTAssertEqual(settings.quietHoursEnd, 8)
    }

    func testQuietHoursAcrossMidnight() throws {
        var settings = AppSettings()
        settings.quietHoursStart = 21
        settings.quietHoursEnd = 8

        XCTAssertTrue(settings.isQuietHour(try localTime(21)))
        XCTAssertTrue(settings.isQuietHour(try localTime(23, 30)))
        XCTAssertTrue(settings.isQuietHour(try localTime(0)))
        XCTAssertTrue(settings.isQuietHour(try localTime(3, 15)))
        XCTAssertTrue(settings.isQuietHour(try localTime(7, 59)))

        XCTAssertFalse(settings.isQuietHour(try localTime(8)))
        XCTAssertFalse(settings.isQuietHour(try localTime(12)))
        XCTAssertFalse(settings.isQuietHour(try localTime(20, 59)))
    }

    func testQuietHoursWithinOneDay() throws {
        var settings = AppSettings()
        settings.quietHoursStart = 13
        settings.quietHoursEnd = 15

        XCTAssertFalse(settings.isQuietHour(try localTime(12, 59)))
        XCTAssertTrue(settings.isQuietHour(try localTime(13)))
        XCTAssertTrue(settings.isQuietHour(try localTime(14, 30)))
        XCTAssertFalse(settings.isQuietHour(try localTime(15)))
        XCTAssertFalse(settings.isQuietHour(try localTime(23)))
    }

    func testEqualStartAndEndMeansNoQuietHours() throws {
        var settings = AppSettings()
        settings.quietHoursStart = 22
        settings.quietHoursEnd = 22
        for hour in [0, 6, 12, 21, 22, 23] {
            XCTAssertFalse(settings.isQuietHour(try localTime(hour)), "hour \(hour)")
        }
    }

    // MARK: Tolerant decoding

    func testEmptyObjectDecodesToDefaults() throws {
        XCTAssertEqual(try decode("{}"), AppSettings())
    }

    func testPartialJSONKeepsDefaultsForMissingKeys() throws {
        let settings = try decode(#"{"userName":"Sam","maxQuestionsPerDay":3,"someFutureSetting":true}"#)
        let defaults = AppSettings()

        XCTAssertEqual(settings.userName, "Sam")
        XCTAssertEqual(settings.maxQuestionsPerDay, 3)

        XCTAssertEqual(settings.quietHoursStart, defaults.quietHoursStart)
        XCTAssertEqual(settings.quietHoursEnd, defaults.quietHoursEnd)
        XCTAssertEqual(settings.claudeModel, defaults.claudeModel)
        XCTAssertEqual(settings.claudeBackgroundModel, defaults.claudeBackgroundModel)
        XCTAssertEqual(settings.llmBackend, defaults.llmBackend)
        XCTAssertEqual(settings.transcriptionEngine, defaults.transcriptionEngine)
        XCTAssertEqual(settings.segmentSeconds, defaults.segmentSeconds)
        XCTAssertEqual(settings.keepAudioDays, defaults.keepAudioDays)
        XCTAssertEqual(settings.questionsEnabled, defaults.questionsEnabled)
        XCTAssertEqual(settings.serverPort, Int(EarshotAPI.defaultPort))
    }

    func testWrongTypesAndUnknownEnumValuesFallBackToDefaults() throws {
        let json = """
        {"segmentSeconds":"ninety","llmBackend":"quantum","transcriptionEngine":"whisperAPI",
         "skipSilentSegments":false,"silenceThresholdDB":-50,"quietHoursStart":null}
        """
        let settings = try decode(json)

        XCTAssertEqual(settings.segmentSeconds, AppSettings().segmentSeconds)
        XCTAssertEqual(settings.llmBackend, .claude)
        XCTAssertEqual(settings.quietHoursStart, AppSettings().quietHoursStart)

        XCTAssertEqual(settings.transcriptionEngine, .whisperAPI)
        XCTAssertFalse(settings.skipSilentSegments)
        XCTAssertEqual(settings.silenceThresholdDB, -50)
    }

    func testEncodeDecodeRoundTrip() throws {
        var settings = AppSettings()
        settings.userName = "Alex"
        settings.llmBackend = .appleOnDevice
        settings.transcriptionEngine = .appleSpeech
        settings.keepAudioDays = 0
        settings.quietHoursStart = 22
        settings.lowBatteryStopLevel = 0.2
        settings.computerUseEnabled = true

        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: data), settings)
    }

    // MARK: Derived values

    func testRemoteWatchSettingsMirrorRecordingFields() {
        var settings = AppSettings()
        settings.segmentSeconds = 90
        settings.silenceThresholdDB = -40
        settings.skipSilentSegments = false
        settings.lowBatteryStopLevel = 0.15

        XCTAssertEqual(settings.remoteWatchSettings,
                       RemoteWatchSettings(segmentSeconds: 90, silenceThresholdDB: -40,
                                           skipSilentSegments: false, lowBatteryStopLevel: 0.15))
        XCTAssertEqual(AppSettings().remoteWatchSettings, RemoteWatchSettings.standard)
    }

    func testProfileBlock() {
        var settings = AppSettings()
        XCTAssertFalse(settings.profileBlock.isEmpty, "a placeholder is used when nothing is set")
        settings.userName = "  Sam  "
        settings.lifeGoals = "Run a half marathon"
        XCTAssertTrue(settings.profileBlock.contains("Name: Sam"))
        XCTAssertTrue(settings.profileBlock.contains("Run a half marathon"))
    }

    func testEffectiveMacNamePrefersDisplayName() {
        var settings = AppSettings()
        settings.macDisplayName = "Studio"
        XCTAssertEqual(settings.effectiveMacName, "Studio")
        settings.macDisplayName = "   "
        XCTAssertFalse(settings.effectiveMacName.isEmpty)
    }
}
