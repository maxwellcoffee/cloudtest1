//  ProtocolTests.swift
//  The watch <-> Mac wire protocol (Shared/EarshotProtocol.swift).

import XCTest
@testable import Earshot

final class ProtocolTests: XCTestCase {

    /// Values chosen to be exactly representable so header strings round-trip bit for bit.
    private let sample = SegmentMeta(id: "seg-42", device: "Apple Watch",
                                     startedAt: Date(timeIntervalSince1970: 1_763_150_400.5),
                                     duration: 120.25, avgPower: -32.5, peakPower: -3.25,
                                     speechRatio: 0.375, reason: .voiceAnswer)

    // MARK: SegmentMeta headers

    func testHeaderFieldsUseProtocolHeaderNames() {
        let headers = sample.headerFields()
        XCTAssertEqual(headers.count, 8)
        XCTAssertEqual(headers[EarshotAPI.Header.segmentID], "seg-42")
        XCTAssertEqual(headers[EarshotAPI.Header.device], "Apple Watch")
        XCTAssertEqual(headers[EarshotAPI.Header.reason], "voiceAnswer")
        XCTAssertEqual(headers["X-Earshot-Started-At"].flatMap { Double($0) }, 1_763_150_400.5)
        XCTAssertEqual(headers["X-Earshot-Duration"].flatMap { Double($0) }, 120.25)
    }

    func testHeaderFieldsRoundTrip() throws {
        let parsed = try XCTUnwrap(SegmentMeta(headers: sample.headerFields()))
        XCTAssertEqual(parsed, sample)
    }

    func testEveryReasonRoundTrips() throws {
        for reason in SegmentReason.allCases {
            var meta = sample
            meta.reason = reason
            XCTAssertEqual(SegmentMeta(headers: meta.headerFields())?.reason, reason)
        }
    }

    func testHeaderParsingIsCaseInsensitive() {
        var lower: [String: String] = [:]
        var upper: [String: String] = [:]
        for (key, value) in sample.headerFields() {
            lower[key.lowercased()] = value
            upper[key.uppercased()] = value
        }
        XCTAssertEqual(SegmentMeta(headers: lower), sample)
        XCTAssertEqual(SegmentMeta(headers: upper), sample)
    }

    func testHeaderParsingIgnoresUnrelatedHeaders() {
        // What the Mac server sees: lower-cased keys plus ordinary HTTP headers.
        var headers: [String: String] = ["content-type": "audio/mp4", "authorization": "Bearer token",
                                         "content-length": "1024", "host": "192.168.1.20:8737"]
        for (key, value) in sample.headerFields() { headers[key.lowercased()] = value }
        XCTAssertEqual(SegmentMeta(headers: headers), sample)
    }

    func testMissingOrInvalidRequiredHeadersFail() {
        var headers = sample.headerFields()
        headers[EarshotAPI.Header.segmentID] = nil
        XCTAssertNil(SegmentMeta(headers: headers), "id is required")

        headers = sample.headerFields()
        headers[EarshotAPI.Header.segmentID] = ""
        XCTAssertNil(SegmentMeta(headers: headers), "id must not be empty")

        headers = sample.headerFields()
        headers[EarshotAPI.Header.startedAt] = nil
        XCTAssertNil(SegmentMeta(headers: headers), "start time is required")

        headers = sample.headerFields()
        headers[EarshotAPI.Header.startedAt] = "yesterday"
        XCTAssertNil(SegmentMeta(headers: headers), "start time must be numeric")

        XCTAssertNil(SegmentMeta(headers: [:]))
    }

    func testOptionalHeadersFallBackToDefaults() throws {
        let meta = try XCTUnwrap(SegmentMeta(headers: ["x-earshot-segment-id": "only-id",
                                                       "x-earshot-started-at": "1763150400"]))
        XCTAssertEqual(meta.id, "only-id")
        XCTAssertEqual(meta.startedAt.timeIntervalSince1970, 1_763_150_400)
        XCTAssertEqual(meta.device, "watch")
        XCTAssertEqual(meta.duration, 0)
        XCTAssertEqual(meta.avgPower, -160)
        XCTAssertEqual(meta.peakPower, -160)
        XCTAssertEqual(meta.speechRatio, 1)
        XCTAssertEqual(meta.reason, .rotation)
    }

    func testUnknownReasonFallsBackToRotation() {
        var headers = sample.headerFields()
        headers[EarshotAPI.Header.reason] = "teleported"
        XCTAssertEqual(SegmentMeta(headers: headers)?.reason, .rotation)
    }

    // MARK: JSON bodies

    func testSyncResponseEncodesDatesAsSecondsSince1970() throws {
        let created = Date(timeIntervalSince1970: 1_763_150_000)
        let expires = Date(timeIntervalSince1970: 1_763_157_600)
        let prompts = [
            WirePrompt(id: "p1", kind: .question, title: "Gym today?",
                       body: "You said you'd go after work.",
                       choices: [PromptChoice(id: "yes", title: "Yes"), PromptChoice(id: "no", title: "Not today")],
                       allowsFreeText: true, allowsVoice: true, createdAt: created, expiresAt: nil, priority: 3),
            WirePrompt(id: "p2", kind: .approval, title: "Send draft?", body: "Draft email to Sam",
                       choices: [PromptChoice(id: "approve", title: "Approve"), PromptChoice(id: "deny", title: "Deny")],
                       allowsFreeText: false, allowsVoice: false, createdAt: created, expiresAt: expires, priority: 5),
        ]
        let today = TodaySnapshot(headline: "Shipped the beta", wordsToday: 1200, minutesRecorded: 95.5,
                                  openTasks: 2, highlights: ["Beta shipped", "Lunch with Sam"], nextUp: "Dentist 4 PM")
        let response = SyncResponse(serverTime: Date(timeIntervalSince1970: 1_763_150_400), macName: "Studio",
                                    prompts: prompts, today: today, settings: .standard)

        let data = try EarshotAPI.makeEncoder().encode(response)
        let json = try JSONValue.parse(data)
        XCTAssertEqual(json["serverTime"]?.doubleValue, 1_763_150_400)
        XCTAssertEqual(json["prompts"]?[0]?["createdAt"]?.doubleValue, 1_763_150_000)
        XCTAssertNil(json["prompts"]?[0]?["expiresAt"], "nil optionals are omitted")
        XCTAssertEqual(json["prompts"]?[1]?["expiresAt"]?.doubleValue, 1_763_157_600)
        XCTAssertEqual(json["prompts"]?[1]?["kind"]?.stringValue, "approval")
        XCTAssertEqual(json["settings"]?["segmentSeconds"]?.intValue, RemoteWatchSettings.standard.segmentSeconds)

        let decoded = try EarshotAPI.makeDecoder().decode(SyncResponse.self, from: data)
        XCTAssertEqual(decoded, response)
    }

    func testDecoderReadsNumericDates() throws {
        let json = #"{"macName":"Studio","protocolVersion":1,"serverTime":1763150400}"#
        let hello = try EarshotAPI.makeDecoder().decode(ServerHello.self, from: Data(json.utf8))
        XCTAssertEqual(hello.serverTime, Date(timeIntervalSince1970: 1_763_150_400))
        XCTAssertEqual(hello.protocolVersion, EarshotAPI.protocolVersion)
    }

    func testWatchStatusReportDecodesWithoutOptionalDates() throws {
        let json = """
        {"deviceName":"Watch","isRecording":true,"batteryLevel":0.8,"queuedSegments":2,
         "queuedBytes":123456,"recordedSecondsToday":3600,"appVersion":"1.0","deliveredPromptIDs":["p1"]}
        """
        let report = try EarshotAPI.makeDecoder().decode(WatchStatusReport.self, from: Data(json.utf8))
        XCTAssertNil(report.pausedUntil)
        XCTAssertNil(report.lastSegmentAt)
        XCTAssertTrue(report.isRecording)
        XCTAssertEqual(report.batteryLevel, 0.8, accuracy: 0.0001)
        XCTAssertEqual(report.queuedSegments, 2)
        XCTAssertEqual(report.queuedBytes, 123_456)
        XCTAssertEqual(report.recordedSecondsToday, 3600)
        XCTAssertEqual(report.deliveredPromptIDs, ["p1"])
    }

    func testPromptAnswerRoundTrip() throws {
        let answer = PromptAnswer(promptID: "p1", mode: .voiceWindow,
                                  answeredAt: Date(timeIntervalSince1970: 1_763_150_400), voiceWindowSeconds: 20)
        let data = try EarshotAPI.makeEncoder().encode(answer)
        XCTAssertEqual(try EarshotAPI.makeDecoder().decode(PromptAnswer.self, from: data), answer)

        let json = try JSONValue.parse(data)
        XCTAssertEqual(json["mode"]?.stringValue, "voiceWindow")
        XCTAssertEqual(json["answeredAt"]?.doubleValue, 1_763_150_400)
        XCTAssertNil(json["choiceID"])
        XCTAssertNil(json["text"])
    }

    func testRequestAndBookmarkRoundTrip() throws {
        let request = WatchRequest(id: "r1", kind: .command, text: "Draft an email to Sam",
                                   createdAt: Date(timeIntervalSince1970: 1_763_150_400))
        let bookmark = Bookmark(id: "b1", kind: .privacyPauseStart, at: Date(timeIntervalSince1970: 1_763_150_460),
                                note: nil)
        let encoder = EarshotAPI.makeEncoder()
        let decoder = EarshotAPI.makeDecoder()
        XCTAssertEqual(try decoder.decode(WatchRequest.self, from: try encoder.encode(request)), request)
        XCTAssertEqual(try decoder.decode(Bookmark.self, from: try encoder.encode(bookmark)), bookmark)
        XCTAssertEqual(try JSONValue.parse(try encoder.encode(bookmark))["kind"]?.stringValue, "privacyPauseStart")
    }

    // MARK: Constants

    func testAPIConstants() {
        XCTAssertEqual(EarshotAPI.defaultPort, 8737)
        XCTAssertEqual(EarshotAPI.bonjourType, "_earshot._tcp")
        let paths = [EarshotAPI.Path.hello, EarshotAPI.Path.pair, EarshotAPI.Path.segments, EarshotAPI.Path.sync,
                     EarshotAPI.Path.answers, EarshotAPI.Path.requests, EarshotAPI.Path.bookmarks]
        XCTAssertEqual(Set(paths).count, paths.count)
        for path in paths {
            XCTAssertTrue(path.hasPrefix("/api/v1/"), path)
        }
    }
}
