//  ClaudeBodyTests.swift
//  Messages API request bodies built by ClaudeClient.makeBody, plus response parsing.

import XCTest
@testable import Earshot

final class ClaudeBodyTests: XCTestCase {

    private let messages: [JSONValue] = [ClaudeClient.userMessage("Summarise my morning.")]

    // MARK: Server-side fallbacks

    func testOpusGetsFallbacksAndBetaHeader() {
        let built = ClaudeClient.makeBody(model: "claude-opus-5-5", system: "You are Earshot.", messages: messages)
        XCTAssertEqual(built.body["fallbacks"], JSONValue.string("default"))
        XCTAssertEqual(built.betas, [ClaudeClient.fallbackBeta])
        XCTAssertEqual(ClaudeClient.fallbackBeta, "server-side-fallback-2026-07-01")
        XCTAssertTrue(ClaudeClient.supportsServerFallback("claude-opus-5-5"))
    }

    func testHaikuGetsNoFallbacks() {
        let built = ClaudeClient.makeBody(model: "claude-haiku-5-5", system: "You are Earshot.", messages: messages)
        XCTAssertNil(built.body["fallbacks"])
        XCTAssertTrue(built.betas.isEmpty)
        XCTAssertFalse(ClaudeClient.supportsServerFallback("claude-haiku-5-5"))
        XCTAssertEqual(built.body["model"]?.stringValue, "claude-haiku-5-5")
    }

    // MARK: Core fields

    func testModelMaxTokensAndMessages() {
        let built = ClaudeClient.makeBody(model: "claude-opus-5-5", system: nil, messages: messages, maxTokens: 4000)
        XCTAssertEqual(built.body["model"]?.stringValue, "claude-opus-5-5")
        XCTAssertEqual(built.body["max_tokens"]?.intValue, 4000)
        XCTAssertTrue(built.body.encodedString().contains(#""max_tokens":4000"#),
                      "max_tokens must be sent as an integer literal")
        XCTAssertEqual(built.body["messages"]?.arrayValue?.count, 1)
        XCTAssertEqual(built.body["messages"]?[0]?["role"]?.stringValue, "user")
        XCTAssertEqual(built.body["messages"]?[0]?["content"]?[0]?["type"]?.stringValue, "text")
        XCTAssertEqual(built.body["messages"]?[0]?["content"]?[0]?["text"]?.stringValue, "Summarise my morning.")
    }

    func testDefaultMaxTokens() {
        let built = ClaudeClient.makeBody(model: "claude-opus-5-5", system: nil, messages: messages)
        XCTAssertEqual(built.body["max_tokens"]?.intValue, 16_000)
    }

    func testNoSamplingOrBudgetParameters() {
        let built = ClaudeClient.makeBody(model: "claude-opus-5-5", system: "s", messages: messages,
                                          effort: "high", thinkingDisplay: "summarized")
        for key in ["temperature", "top_p", "top_k", "tool_choice", "effort"] {
            XCTAssertNil(built.body[key], "\(key) must not be sent")
        }
        XCTAssertNil(built.body["thinking"]?["budget_tokens"])
    }

    // MARK: System prompt

    func testSystemPromptIsOneCachedTextBlock() throws {
        let built = ClaudeClient.makeBody(model: "claude-opus-5-5", system: "Persona and rules", messages: messages)
        let blocks = try XCTUnwrap(built.body["system"]?.arrayValue)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0]["type"]?.stringValue, "text")
        XCTAssertEqual(blocks[0]["text"]?.stringValue, "Persona and rules")
        XCTAssertEqual(blocks[0]["cache_control"]?["type"]?.stringValue, "ephemeral")
    }

    func testEmptyOrMissingSystemPromptIsOmitted() {
        XCTAssertNil(ClaudeClient.makeBody(model: "claude-opus-5-5", system: nil, messages: messages).body["system"])
        XCTAssertNil(ClaudeClient.makeBody(model: "claude-opus-5-5", system: "", messages: messages).body["system"])
    }

    // MARK: output_config

    func testEffortLivesInOutputConfig() {
        let built = ClaudeClient.makeBody(model: "claude-opus-5-5", system: "s", messages: messages, effort: "medium")
        XCTAssertEqual(built.body["output_config"]?["effort"]?.stringValue, "medium")
        XCTAssertNil(built.body["output_config"]?["format"])
        XCTAssertNil(built.body["effort"], "effort is not a top-level parameter")
    }

    func testJSONSchemaBecomesOutputConfigFormat() {
        let schema = Schema.object([("summary", Schema.string()), ("mood", Schema.enumeration(["good", "bad"]))])
        let built = ClaudeClient.makeBody(model: "claude-opus-5-5", system: nil, messages: messages, jsonSchema: schema)
        let format = built.body["output_config"]?["format"]
        XCTAssertEqual(format?["type"]?.stringValue, "json_schema")
        XCTAssertEqual(format?["schema"], schema)
        XCTAssertNil(built.body["output_config"]?["effort"])
        XCTAssertNil(built.body["output_format"])
        XCTAssertNil(built.body["format"])
    }

    func testEffortAndSchemaTogether() {
        let schema = Schema.object([("answer", Schema.string())])
        let built = ClaudeClient.makeBody(model: "claude-haiku-5-5", system: "s", messages: messages,
                                          effort: "low", jsonSchema: schema)
        let config = built.body["output_config"]
        XCTAssertEqual(config?["effort"]?.stringValue, "low")
        XCTAssertEqual(config?["format"]?["schema"], schema)
        XCTAssertEqual(config?.objectValue?.count, 2)
    }

    func testNoEffortAndNoSchemaOmitsOutputConfig() {
        XCTAssertNil(ClaudeClient.makeBody(model: "claude-opus-5-5", system: "s", messages: messages).body["output_config"])
        XCTAssertNil(ClaudeClient.makeBody(model: "claude-opus-5-5", system: "s", messages: messages,
                                           effort: "").body["output_config"])
    }

    // MARK: Tools and thinking

    func testToolsArePassedThroughAndEmptyToolsOmitted() {
        let tool: JSONValue = [
            "name": "create_note",
            "description": "Create a markdown note",
            "input_schema": Schema.object([("title", Schema.string()), ("body", Schema.string())]),
        ]
        let toolset: JSONValue = ["type": "computer_toolset_20260801"]
        let built = ClaudeClient.makeBody(model: "claude-opus-5-5", system: nil, messages: messages, tools: [tool, toolset])
        XCTAssertEqual(built.body["tools"], JSONValue.array([tool, toolset]))

        let none = ClaudeClient.makeBody(model: "claude-opus-5-5", system: nil, messages: messages, tools: [])
        XCTAssertNil(none.body["tools"])
    }

    func testThinkingDisplayUsesAdaptiveThinking() {
        let built = ClaudeClient.makeBody(model: "claude-opus-5-5", system: nil, messages: messages,
                                          thinkingDisplay: "summarized")
        XCTAssertEqual(built.body["thinking"]?["type"]?.stringValue, "adaptive")
        XCTAssertEqual(built.body["thinking"]?["display"]?.stringValue, "summarized")
        XCTAssertNil(ClaudeClient.makeBody(model: "claude-opus-5-5", system: nil, messages: messages).body["thinking"])
    }

    // MARK: Content blocks

    func testToolResultBlocks() {
        let computer = ClaudeClient.toolResult(toolUseID: "tu_1", text: "", toolsetName: "computer")
        XCTAssertEqual(computer["type"]?.stringValue, "tool_result")
        XCTAssertEqual(computer["tool_use_id"]?.stringValue, "tu_1")
        XCTAssertEqual(computer["toolset_name"]?.stringValue, "computer")
        XCTAssertEqual(computer["content"]?[0]?["text"]?.stringValue, "OK", "empty text is replaced")
        XCTAssertNil(computer["is_error"])

        let failure = ClaudeClient.toolResult(toolUseID: "tu_2", text: "Reminders access denied", isError: true)
        XCTAssertEqual(failure["is_error"], JSONValue.bool(true))
        XCTAssertEqual(failure["content"]?[0]?["text"]?.stringValue, "Reminders access denied")
        XCTAssertNil(failure["toolset_name"])
    }

    func testImageBlockIsBase64PNG() {
        let block = ClaudeClient.imageBlock(pngData: Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(block["type"]?.stringValue, "image")
        XCTAssertEqual(block["source"]?["type"]?.stringValue, "base64")
        XCTAssertEqual(block["source"]?["media_type"]?.stringValue, "image/png")
        XCTAssertEqual(block["source"]?["data"]?.stringValue, "AQID")
    }

    func testUserMessageWithContentBlocks() {
        let message = ClaudeClient.userMessage(content: [ClaudeClient.textBlock("Look"),
                                                         ClaudeClient.imageBlock(pngData: Data([0xFF]))])
        XCTAssertEqual(message["role"]?.stringValue, "user")
        XCTAssertEqual(message["content"]?.arrayValue?.count, 2)
        XCTAssertEqual(message["content"]?[1]?["type"]?.stringValue, "image")
    }

    // MARK: Responses

    func testResponseParsing() throws {
        let raw = try JSONValue.parse(#"""
        {"model":"claude-opus-5-5","stop_reason":"tool_use",
         "content":[{"type":"thinking","thinking":"Plan the click","signature":"sig"},
                    {"type":"text","text":"Opening Notes."},
                    {"type":"tool_use","id":"tu_1","name":"left_click","toolset_name":"computer",
                     "input":{"coordinate":[10,20]}},
                    {"type":"tool_use","id":"tu_2","name":"create_note","input":{"title":"Groceries"}}],
         "usage":{"input_tokens":120,"output_tokens":45}}
        """#)
        let response = ClaudeResponse(raw: raw)

        XCTAssertEqual(response.model, "claude-opus-5-5")
        XCTAssertEqual(response.stopReason, "tool_use")
        XCTAssertEqual(response.text, "Opening Notes.")
        XCTAssertEqual(response.thinkingNotes, ["Plan the click"])
        XCTAssertEqual(response.toolUses.count, 2)
        XCTAssertEqual(response.toolUses.first?.name, "left_click")
        XCTAssertEqual(response.toolUses.first?.toolsetName, "computer")
        XCTAssertEqual(response.toolUses.first?.input["coordinate"]?[1]?.intValue, 20)
        XCTAssertEqual(response.toolUses.last?.id, "tu_2")
        XCTAssertNil(response.toolUses.last?.toolsetName)
        XCTAssertEqual(response.inputTokens, 120)
        XCTAssertEqual(response.outputTokens, 45)

        // The assistant turn is replayed verbatim, thinking block and signature included.
        XCTAssertEqual(response.assistantMessage["role"]?.stringValue, "assistant")
        XCTAssertEqual(response.assistantMessage["content"], raw["content"])
    }

    func testRefusalCategory() throws {
        let raw = try JSONValue.parse(#"{"stop_reason":"refusal","stop_details":{"category":"cyber"},"content":[]}"#)
        let response = ClaudeResponse(raw: raw)
        XCTAssertEqual(response.stopReason, "refusal")
        XCTAssertEqual(response.refusalCategory, "cyber")
        XCTAssertEqual(response.text, "")
        XCTAssertTrue(response.toolUses.isEmpty)
    }

    func testErrorsHaveUserFacingDescriptions() {
        let errors: [ClaudeError] = [.missingAPIKey, .http(status: 529, type: "overloaded_error", message: "Overloaded"),
                                     .refusal(category: nil), .truncated, .invalidResponse("not JSON")]
        for error in errors {
            XCTAssertFalse((error.errorDescription ?? "").isEmpty)
        }
        XCTAssertTrue(ClaudeError.http(status: 529, type: "overloaded_error", message: "Overloaded")
            .errorDescription?.contains("529") == true)
    }
}
