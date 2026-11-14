//  JSONValue.swift
//  A lossless JSON tree. Used for Claude API request/response bodies so that
//  assistant content (thinking blocks, tool_use blocks, toolset_name, ...) can
//  be replayed to the API byte-for-byte equivalent, as the API requires.

import Foundation

enum JSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    // MARK: Codable

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let b = try? c.decode(Bool.self) {
            self = .bool(b)
        } else if let n = try? c.decode(Double.self) {
            self = .number(n)
        } else if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let a = try? c.decode([JSONValue].self) {
            self = .array(a)
        } else if let o = try? c.decode([String: JSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n):
            // Encode integral values without a fractional part (e.g. max_tokens: 16000).
            if n.rounded() == n, abs(n) < 9.0e15 {
                try c.encode(Int64(n))
            } else {
                try c.encode(n)
            }
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }

    // MARK: Accessors

    subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }

    subscript(index: Int) -> JSONValue? {
        if case .array(let a) = self, index >= 0, index < a.count { return a[index] }
        return nil
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var doubleValue: Double? {
        if case .number(let n) = self { return n }
        return nil
    }

    var intValue: Int? {
        if case .number(let n) = self { return Int(n) }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }

    var arrayValue: [JSONValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let o) = self { return o }
        return nil
    }

    var isNull: Bool {
        if case .null = self { return true }
        return false
    }

    /// Returns a copy with `key` set (only meaningful for objects).
    func setting(_ key: String, _ value: JSONValue) -> JSONValue {
        guard case .object(var o) = self else { return self }
        o[key] = value
        return .object(o)
    }

    // MARK: Conversion

    func encodedData(pretty: Bool = false) throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        return try e.encode(self)
    }

    func encodedString(pretty: Bool = false) -> String {
        guard let d = try? encodedData(pretty: pretty) else { return "null" }
        return String(decoding: d, as: UTF8.self)
    }

    static func parse(_ data: Data) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: data)
    }

    static func parse(_ string: String) throws -> JSONValue {
        try parse(Data(string.utf8))
    }

    /// Converts any Encodable into a JSONValue.
    static func from<T: Encodable>(_ value: T) throws -> JSONValue {
        let data = try JSONEncoder().encode(value)
        return try parse(data)
    }

    /// Decodes this JSON tree into a Decodable type.
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: try encodedData())
    }
}

// MARK: - Literal conveniences

extension JSONValue: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral,
                     ExpressibleByBooleanLiteral, ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral {
    init(stringLiteral value: String) { self = .string(value) }
    init(integerLiteral value: Int) { self = .number(Double(value)) }
    init(floatLiteral value: Double) { self = .number(value) }
    init(booleanLiteral value: Bool) { self = .bool(value) }
    init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
    init(dictionaryLiteral elements: (String, JSONValue)...) {
        var o: [String: JSONValue] = [:]
        for (k, v) in elements { o[k] = v }
        self = .object(o)
    }
}

// MARK: - JSON Schema helpers (for structured outputs and tool input schemas)

/// Small builder for JSON Schemas compatible with Claude structured outputs:
/// every object gets `additionalProperties: false` and all properties required.
enum Schema {
    static func string(_ description: String? = nil) -> JSONValue {
        var o: [String: JSONValue] = ["type": "string"]
        if let description { o["description"] = .string(description) }
        return .object(o)
    }

    static func number(_ description: String? = nil) -> JSONValue {
        var o: [String: JSONValue] = ["type": "number"]
        if let description { o["description"] = .string(description) }
        return .object(o)
    }

    static func integer(_ description: String? = nil) -> JSONValue {
        var o: [String: JSONValue] = ["type": "integer"]
        if let description { o["description"] = .string(description) }
        return .object(o)
    }

    static func boolean(_ description: String? = nil) -> JSONValue {
        var o: [String: JSONValue] = ["type": "boolean"]
        if let description { o["description"] = .string(description) }
        return .object(o)
    }

    static func enumeration(_ values: [String], _ description: String? = nil) -> JSONValue {
        var o: [String: JSONValue] = ["type": "string", "enum": .array(values.map { .string($0) })]
        if let description { o["description"] = .string(description) }
        return .object(o)
    }

    static func array(_ items: JSONValue, _ description: String? = nil) -> JSONValue {
        var o: [String: JSONValue] = ["type": "array", "items": items]
        if let description { o["description"] = .string(description) }
        return .object(o)
    }

    /// All listed properties are required (structured-outputs friendly).
    static func object(_ properties: [(String, JSONValue)], _ description: String? = nil) -> JSONValue {
        var props: [String: JSONValue] = [:]
        for (k, v) in properties { props[k] = v }
        var o: [String: JSONValue] = [
            "type": "object",
            "properties": .object(props),
            "required": .array(properties.map { .string($0.0) }),
            "additionalProperties": false,
        ]
        if let description { o["description"] = .string(description) }
        return .object(o)
    }

    /// Object whose properties are listed but only `required` ones are mandatory
    /// (for tool input schemas, where optional parameters are normal).
    static func object(_ properties: [(String, JSONValue)], required: [String], _ description: String? = nil) -> JSONValue {
        var props: [String: JSONValue] = [:]
        for (k, v) in properties { props[k] = v }
        var o: [String: JSONValue] = [
            "type": "object",
            "properties": .object(props),
            "required": .array(required.map { .string($0) }),
            "additionalProperties": false,
        ]
        if let description { o["description"] = .string(description) }
        return .object(o)
    }
}
