//  HTTPParserTests.swift
//  The pure HTTP/1.1 parser and serializer behind the Mac server.

import XCTest
@testable import Earshot

final class HTTPParserTests: XCTestCase {

    private func bytes(_ text: String) -> Data { Data(text.utf8) }

    /// Joins header lines with CRLF and terminates the head with an empty line.
    private func head(_ lines: [String]) -> String {
        lines.joined(separator: "\r\n") + "\r\n\r\n"
    }

    // MARK: Incomplete input

    func testEmptyBufferReturnsNil() {
        XCTAssertNil(HTTPParser.parse(Data()))
    }

    func testPartialHeadReturnsNil() {
        XCTAssertNil(HTTPParser.parse(bytes("GET /api/v1/hello HTTP/1.1\r\nHost: mac.local\r\n")))
        XCTAssertNil(HTTPParser.parse(bytes("POST /api/v1/sync HTT")))
    }

    func testPartialBodyReturnsNil() {
        let raw = head(["POST /api/v1/answers HTTP/1.1", "Content-Type: application/json", "Content-Length: 40"])
            + #"{"promptID":"p1""#
        XCTAssertNil(HTTPParser.parse(bytes(raw)))
    }

    func testBodyArrivingInChunksParsesOnceComplete() throws {
        let body = #"{"promptID":"p1","mode":"dismissed","answeredAt":1763150400}"#
        let full = bytes(head(["POST /api/v1/answers HTTP/1.1", "Content-Length: \(body.utf8.count)"]) + body)
        for cut in [1, full.count / 2, full.count - 1] {
            XCTAssertNil(HTTPParser.parse(full.prefix(cut)), "only \(cut) of \(full.count) bytes")
        }
        let parsed = try XCTUnwrap(HTTPParser.parse(full))
        XCTAssertEqual(parsed.request.body, Data(body.utf8))
        XCTAssertEqual(parsed.consumed, full.count)
    }

    // MARK: Complete requests

    func testParsesMethodPathQueryHeadersAndBody() throws {
        let body = #"{"deviceName":"Watch","isRecording":true}"#
        let raw = head([
            "POST /api/v1/sync?device=watch&v=1 HTTP/1.1",
            "Host: 192.168.1.20:8737",
            "Content-Type: application/json",
            "Authorization: Bearer abc123",
            "X-Earshot-Segment-Id: seg-1",
            "Content-Length: \(body.utf8.count)",
        ]) + body
        let data = bytes(raw)

        let parsed = try XCTUnwrap(HTTPParser.parse(data))
        XCTAssertEqual(parsed.consumed, data.count)

        let request = parsed.request
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "/api/v1/sync")
        XCTAssertEqual(request.query["device"], "watch")
        XCTAssertEqual(request.query["v"], "1")
        XCTAssertEqual(request.query.count, 2)

        XCTAssertEqual(request.headers["content-type"], "application/json")
        XCTAssertEqual(request.headers["host"], "192.168.1.20:8737", "only the first colon separates name and value")
        XCTAssertEqual(request.headers["x-earshot-segment-id"], "seg-1")
        XCTAssertNil(request.headers["Content-Type"], "header keys are lower-cased")

        XCTAssertEqual(request.header("AUTHORIZATION"), "Bearer abc123")
        XCTAssertEqual(request.header("Content-Type"), "application/json")
        XCTAssertEqual(request.header("content-length"), "\(body.utf8.count)")
        XCTAssertNil(request.header("X-Missing"))

        XCTAssertEqual(request.body, Data(body.utf8))
    }

    func testRequestWithoutBody() throws {
        let raw = head(["GET /api/v1/hello HTTP/1.1", "Host: mac.local", "Accept: */*"])
        let parsed = try XCTUnwrap(HTTPParser.parse(bytes(raw)))
        XCTAssertEqual(parsed.request.method, "GET")
        XCTAssertEqual(parsed.request.path, "/api/v1/hello")
        XCTAssertTrue(parsed.request.query.isEmpty)
        XCTAssertTrue(parsed.request.body.isEmpty)
        XCTAssertEqual(parsed.consumed, raw.utf8.count)
    }

    func testConsumesOnlyTheFirstOfPipelinedRequests() throws {
        let first = head(["POST /api/v1/bookmarks HTTP/1.1", "Content-Length: 2"]) + "{}"
        let second = head(["GET /api/v1/hello HTTP/1.1", "Host: mac.local"])
        let parsed = try XCTUnwrap(HTTPParser.parse(bytes(first + second)))
        XCTAssertEqual(parsed.request.path, "/api/v1/bookmarks")
        XCTAssertEqual(parsed.request.body, bytes("{}"))
        XCTAssertEqual(parsed.consumed, first.utf8.count)
    }

    func testBinaryBodyIsTakenByContentLengthInBytes() throws {
        // Audio bodies are binary and may contain CRLF sequences or invalid UTF-8.
        let audio = Data([0x00, 0x0D, 0x0A, 0x0D, 0x0A, 0xFF, 0xFE, 0x41])
        var data = bytes(head(["POST /api/v1/segments HTTP/1.1", "Content-Type: audio/mp4",
                               "Content-Length: \(audio.count)"]))
        data.append(audio)

        XCTAssertNil(HTTPParser.parse(data.prefix(data.count - 3)))
        let parsed = try XCTUnwrap(HTTPParser.parse(data))
        XCTAssertEqual(parsed.request.body, audio)
        XCTAssertEqual(parsed.consumed, data.count)
    }

    func testMultiByteUTF8BodyLength() throws {
        let body = #"{"text":"café ☕️"}"#
        let raw = head(["POST /api/v1/requests HTTP/1.1", "Content-Length: \(body.utf8.count)"]) + body
        let parsed = try XCTUnwrap(HTTPParser.parse(bytes(raw)))
        XCTAssertEqual(parsed.request.body, Data(body.utf8))
        XCTAssertEqual(parsed.consumed, raw.utf8.count)
    }

    func testMaxBodyBytesIsAboutSixtyFourMegabytes() {
        XCTAssertGreaterThanOrEqual(HTTPParser.maxBodyBytes, 64_000_000)
        XCTAssertLessThanOrEqual(HTTPParser.maxBodyBytes, 64 * 1024 * 1024)
    }

    // MARK: Serialization

    func testSerializeTextResponse() {
        let response = HTTPResponse.text("hello")
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(response.body, bytes("hello"))

        let wire = String(decoding: HTTPParser.serialize(response), as: UTF8.self)
        XCTAssertTrue(wire.hasPrefix("HTTP/1.1 200"), wire)
        XCTAssertTrue(wire.lowercased().contains("\r\ncontent-length: 5\r\n"), wire)
        XCTAssertTrue(wire.hasSuffix("\r\n\r\nhello"), wire)
    }

    func testSerializeJSONResponse() throws {
        let hello = ServerHello(macName: "Studio", protocolVersion: EarshotAPI.protocolVersion,
                                serverTime: Date(timeIntervalSince1970: 1_763_150_400))
        let response = HTTPResponse.json(hello)
        XCTAssertEqual(response.status, 200)
        XCTAssertEqual(try EarshotAPI.makeDecoder().decode(ServerHello.self, from: response.body), hello,
                       "JSON responses use EarshotAPI.makeEncoder (seconds since 1970)")
        let contentType = response.headers.first(where: { $0.key.lowercased() == "content-type" })?.value
        XCTAssertEqual(contentType?.lowercased().hasPrefix("application/json"), true)

        let wire = HTTPParser.serialize(response)
        let text = String(decoding: wire, as: UTF8.self)
        XCTAssertTrue(text.lowercased().contains("\r\ncontent-length: \(response.body.count)\r\n"), text)
        XCTAssertEqual(wire.suffix(response.body.count), response.body)

        let created = HTTPResponse.json(OKResponse(ok: true, message: "saved"), status: 201)
        XCTAssertEqual(created.status, 201)
        XCTAssertTrue(String(decoding: HTTPParser.serialize(created), as: UTF8.self).hasPrefix("HTTP/1.1 201"))
    }

    func testSerializeErrorResponse() throws {
        let response = HTTPResponse.error(401, "Invalid token")
        XCTAssertEqual(response.status, 401)
        XCTAssertEqual(try JSONDecoder().decode(APIErrorBody.self, from: response.body).error, "Invalid token")

        let wire = String(decoding: HTTPParser.serialize(response), as: UTF8.self)
        XCTAssertTrue(wire.hasPrefix("HTTP/1.1 401"), wire)
        XCTAssertTrue(wire.lowercased().contains("\r\ncontent-length: \(response.body.count)\r\n"), wire)

        XCTAssertTrue(String(decoding: HTTPParser.serialize(HTTPResponse.error(404, "Not found")), as: UTF8.self)
            .hasPrefix("HTTP/1.1 404"))
    }

    func testSerializedResponseHasExactlyOneHeadTerminator() {
        let wire = HTTPParser.serialize(HTTPResponse.text("body"))
        let text = String(decoding: wire, as: UTF8.self)
        let parts = text.components(separatedBy: "\r\n\r\n")
        XCTAssertEqual(parts.count, 2, text)
        XCTAssertEqual(parts.last, "body")
    }
}
