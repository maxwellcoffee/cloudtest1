//  JSONValueTests.swift
//  The lossless JSON tree used for every Claude API body.

import XCTest
@testable import Earshot

final class JSONValueTests: XCTestCase {

    func testRoundTripPreservesEveryKindOfValue() throws {
        let source = """
        {"name":"Earshot","count":3,"ratio":0.25,"enabled":true,"missing":null,
         "tags":["a","b"],"nested":{"inner":[1,2,{"deep":false}]}}
        """
        let value = try JSONValue.parse(source)
        let reparsed = try JSONValue.parse(try value.encodedData())
        XCTAssertEqual(reparsed, value)

        XCTAssertEqual(value["name"], JSONValue.string("Earshot"))
        XCTAssertEqual(value["count"], JSONValue.number(3))
        XCTAssertEqual(value["ratio"], JSONValue.number(0.25))
        XCTAssertEqual(value["enabled"], JSONValue.bool(true))
        XCTAssertEqual(value["missing"], JSONValue.null)
        XCTAssertEqual(value["tags"], JSONValue.array([.string("a"), .string("b")]))
        XCTAssertEqual(value["nested"]?["inner"]?[2]?["deep"], JSONValue.bool(false))
    }

    func testPrettyEncodingParsesBackToTheSameValue() throws {
        let value: JSONValue = ["list": [1, 2.5, "three", true, .null], "object": ["k": "v"]]
        let pretty = try value.encodedData(pretty: true)
        XCTAssertEqual(try JSONValue.parse(pretty), value)
    }

    func testIntegralNumbersEncodeWithoutFraction() {
        XCTAssertEqual(JSONValue.number(16000).encodedString(), "16000")
        XCTAssertEqual(JSONValue.number(-3).encodedString(), "-3")
        XCTAssertEqual(JSONValue.number(0).encodedString(), "0")
        XCTAssertEqual(JSONValue.number(1.5).encodedString(), "1.5")

        let body: JSONValue = ["max_tokens": 16000, "model": "claude-opus-5-5"]
        XCTAssertEqual(body.encodedString(), #"{"max_tokens":16000,"model":"claude-opus-5-5"}"#)
    }

    func testObjectKeysAreSortedWhenEncoded() {
        let object: JSONValue = ["zeta": 1, "alpha": "a", "mid": [true]]
        XCTAssertEqual(object.encodedString(), #"{"alpha":"a","mid":[true],"zeta":1}"#)
    }

    func testBooleansAndNumbersStayDistinct() throws {
        let value = try JSONValue.parse("[true, 1, 0, false]")
        XCTAssertEqual(value, JSONValue.array([.bool(true), .number(1), .number(0), .bool(false)]))
        XCTAssertNil(value[1]?.boolValue)
        XCTAssertNil(value[0]?.doubleValue)
    }

    func testEqualityIgnoresKeyOrder() throws {
        let a = try JSONValue.parse(#"{"a":1,"b":[true,null]}"#)
        let b = try JSONValue.parse(#"{"b":[true,null],"a":1}"#)
        XCTAssertEqual(a, b)
        XCTAssertEqual(Set([a, b]).count, 1)
    }

    func testLiteralsBuildTheExpectedCases() {
        let value: JSONValue = ["s": "text", "i": 7, "d": 2.5, "b": false, "a": [1, "two", .null]]
        XCTAssertEqual(value["s"]?.stringValue, "text")
        XCTAssertEqual(value["i"]?.intValue, 7)
        XCTAssertEqual(value["i"]?.doubleValue, 7)
        XCTAssertEqual(value["d"]?.doubleValue, 2.5)
        XCTAssertEqual(value["b"]?.boolValue, false)
        XCTAssertEqual(value["a"]?.arrayValue?.count, 3)
        XCTAssertEqual(value["a"]?[0]?.intValue, 1)
        XCTAssertEqual(value["a"]?[1]?.stringValue, "two")
        XCTAssertEqual(value["a"]?[2]?.isNull, true)
        XCTAssertEqual(value.objectValue?.count, 5)
    }

    func testSubscriptsReturnNilForWrongShapesAndMissingEntries() {
        let array: JSONValue = [1, 2, 3]
        let object: JSONValue = ["k": "v"]

        XCTAssertEqual(array[0], JSONValue.number(1))
        XCTAssertEqual(array[2], JSONValue.number(3))
        XCTAssertNil(array[3])
        XCTAssertNil(array[-1])
        XCTAssertNil(array["k"])

        XCTAssertEqual(object["k"], JSONValue.string("v"))
        XCTAssertNil(object["missing"])
        XCTAssertNil(object[0])

        XCTAssertNil(JSONValue.string("x")["k"])
        XCTAssertNil(JSONValue.null[0])
    }

    func testTypedAccessorsRejectOtherCases() {
        XCTAssertNil(JSONValue.string("1").intValue)
        XCTAssertNil(JSONValue.string("1").doubleValue)
        XCTAssertNil(JSONValue.number(1).stringValue)
        XCTAssertNil(JSONValue.number(1).boolValue)
        XCTAssertNil(JSONValue.bool(true).arrayValue)
        XCTAssertNil(JSONValue.array([]).objectValue)
        XCTAssertFalse(JSONValue.string("").isNull)
        XCTAssertTrue(JSONValue.null.isNull)
    }

    func testSettingAddsKeysOnlyToObjects() {
        let object: JSONValue = ["a": 1]
        let updated = object.setting("b", "two")
        XCTAssertEqual(updated["a"], JSONValue.number(1))
        XCTAssertEqual(updated["b"], JSONValue.string("two"))
        XCTAssertNil(object["b"], "setting(_:_:) returns a copy")

        let replaced = updated.setting("a", false)
        XCTAssertEqual(replaced["a"], JSONValue.bool(false))

        let array: JSONValue = [1]
        XCTAssertEqual(array.setting("b", true), array)
    }

    func testConversionFromAndToCodableTypes() throws {
        let ack = SegmentAck(id: "seg-1", accepted: true, message: nil)
        let json = try JSONValue.from(ack)
        XCTAssertEqual(json["id"]?.stringValue, "seg-1")
        XCTAssertEqual(json["accepted"]?.boolValue, true)
        XCTAssertNil(json["message"], "nil optionals are omitted")
        XCTAssertEqual(try json.decode(SegmentAck.self), ack)
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try JSONValue.parse("{not json"))
        XCTAssertThrowsError(try JSONValue.parse(Data()))
    }

    func testTopLevelScalarsParse() throws {
        XCTAssertEqual(try JSONValue.parse("42"), JSONValue.number(42))
        XCTAssertEqual(try JSONValue.parse("\"hi\""), JSONValue.string("hi"))
        XCTAssertEqual(try JSONValue.parse("null"), JSONValue.null)
    }
}
