//  SchemaTests.swift
//  JSON Schema builders used for structured outputs and tool input schemas.

import XCTest
@testable import Earshot

final class SchemaTests: XCTestCase {

    func testObjectRequiresEveryPropertyAndForbidsExtras() throws {
        let schema = Schema.object([
            ("title", Schema.string("Short title")),
            ("priority", Schema.integer()),
            ("score", Schema.number()),
            ("urgent", Schema.boolean()),
        ], "An item")

        XCTAssertEqual(schema["type"]?.stringValue, "object")
        XCTAssertEqual(schema["additionalProperties"], JSONValue.bool(false))
        XCTAssertEqual(schema["required"], JSONValue.array(["title", "priority", "score", "urgent"]),
                       "required lists every property, in declaration order")
        XCTAssertEqual(schema["description"]?.stringValue, "An item")

        let properties = try XCTUnwrap(schema["properties"]?.objectValue)
        XCTAssertEqual(Set(properties.keys), ["title", "priority", "score", "urgent"])
        XCTAssertEqual(properties["title"]?["type"]?.stringValue, "string")
        XCTAssertEqual(properties["title"]?["description"]?.stringValue, "Short title")
        XCTAssertEqual(properties["priority"]?["type"]?.stringValue, "integer")
        XCTAssertNil(properties["priority"]?["description"])
        XCTAssertEqual(properties["score"]?["type"]?.stringValue, "number")
        XCTAssertEqual(properties["urgent"]?["type"]?.stringValue, "boolean")
    }

    func testObjectWithoutDescriptionOmitsTheKey() {
        let schema = Schema.object([("text", Schema.string())])
        XCTAssertNil(schema["description"])
        XCTAssertEqual(schema["required"], JSONValue.array(["text"]))
    }

    func testObjectWithExplicitRequiredList() {
        let schema = Schema.object([
            ("query", Schema.string("Search terms")),
            ("days", Schema.integer("How many days back")),
        ], required: ["query"], "Tool input")

        XCTAssertEqual(schema["type"]?.stringValue, "object")
        XCTAssertEqual(schema["required"], JSONValue.array(["query"]))
        XCTAssertEqual(schema["additionalProperties"], JSONValue.bool(false))
        XCTAssertEqual(schema["properties"]?.objectValue?.count, 2)
        XCTAssertEqual(schema["properties"]?["days"]?["description"]?.stringValue, "How many days back")
        XCTAssertEqual(schema["description"]?.stringValue, "Tool input")
    }

    func testObjectWithNoRequiredProperties() {
        let schema = Schema.object([("note", Schema.string())], required: [])
        XCTAssertEqual(schema["required"], JSONValue.array([]))
        XCTAssertEqual(schema["additionalProperties"], JSONValue.bool(false))
    }

    func testEnumeration() {
        let kinds = Schema.enumeration(["task", "idea", "goal"], "Kind of insight")
        XCTAssertEqual(kinds["type"]?.stringValue, "string")
        XCTAssertEqual(kinds["enum"], JSONValue.array(["task", "idea", "goal"]))
        XCTAssertEqual(kinds["description"]?.stringValue, "Kind of insight")
        XCTAssertNil(Schema.enumeration(["a"])["description"])
    }

    func testArrayOfObjectsKeepsNestedConstraints() {
        let list = Schema.array(Schema.object([("text", Schema.string()), ("confidence", Schema.number())]), "Items")
        XCTAssertEqual(list["type"]?.stringValue, "array")
        XCTAssertEqual(list["description"]?.stringValue, "Items")
        XCTAssertEqual(list["items"]?["type"]?.stringValue, "object")
        XCTAssertEqual(list["items"]?["additionalProperties"], JSONValue.bool(false))
        XCTAssertEqual(list["items"]?["required"], JSONValue.array(["text", "confidence"]))
    }

    func testNestedSchemaEncodesAsValidJSON() throws {
        let schema = Schema.object([
            ("insights", Schema.array(Schema.object([
                ("kind", Schema.enumeration(["task", "fact"])),
                ("title", Schema.string()),
            ]))),
            ("summary", Schema.string()),
        ])
        let encoded = schema.encodedString()
        XCTAssertTrue(encoded.contains(#""additionalProperties":false"#))
        XCTAssertEqual(try JSONValue.parse(encoded), schema)
        XCTAssertEqual(schema["properties"]?["insights"]?["items"]?["properties"]?["kind"]?["enum"],
                       JSONValue.array(["task", "fact"]))
    }
}
