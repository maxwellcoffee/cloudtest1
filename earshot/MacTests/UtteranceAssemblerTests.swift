//  UtteranceAssemblerTests.swift
//  Merging recogniser pieces into sentence-like utterances.

import XCTest
@testable import Earshot

final class UtteranceAssemblerTests: XCTestCase {

    private let segmentStart = Date(timeIntervalSince1970: 1_763_150_400)

    private func assemble(_ pieces: [TranscriptPiece], segmentID: String = "seg-1") -> [Utterance] {
        UtteranceAssembler.assemble(pieces: pieces, segmentID: segmentID, segmentStart: segmentStart)
    }

    /// Whitespace-separated words, so the test does not depend on how pieces are joined.
    private func words(_ texts: [String]) -> [String] {
        texts.joined(separator: " ").split(whereSeparator: { $0.isWhitespace }).map { String($0) }
    }

    private func collapsed(_ text: String) -> String {
        words([text]).joined(separator: " ")
    }

    private func offset(_ date: Date) -> TimeInterval {
        date.timeIntervalSince(segmentStart)
    }

    func testNoPiecesGiveNoUtterances() {
        XCTAssertTrue(assemble([]).isEmpty)
    }

    func testBlankPiecesGiveNoUtterances() {
        let pieces = [TranscriptPiece(start: 0, end: 1, text: "   "), TranscriptPiece(start: 1, end: 2, text: "")]
        XCTAssertTrue(assemble(pieces).isEmpty)
    }

    func testMergesFragmentsIntoSentences() {
        let pieces = [
            TranscriptPiece(start: 0.0, end: 0.6, text: "We should ship"),
            TranscriptPiece(start: 0.6, end: 1.4, text: "the beta on Friday."),
            TranscriptPiece(start: 1.5, end: 2.1, text: "Then I will call"),
            TranscriptPiece(start: 2.1, end: 3.2, text: "Sam about the contract."),
        ]
        let utterances = assemble(pieces)

        XCTAssertEqual(utterances.map { collapsed($0.text) },
                       ["We should ship the beta on Friday.", "Then I will call Sam about the contract."])
        guard utterances.count == 2 else { return }
        XCTAssertEqual(offset(utterances[0].startedAt), 0.0, accuracy: 0.01)
        XCTAssertEqual(offset(utterances[0].endedAt), 1.4, accuracy: 0.01)
        XCTAssertEqual(offset(utterances[1].startedAt), 1.5, accuracy: 0.01)
        XCTAssertEqual(offset(utterances[1].endedAt), 3.2, accuracy: 0.01)
    }

    func testLongPauseStartsANewUtterance() {
        let pieces = [
            TranscriptPiece(start: 0.0, end: 1.2, text: "so anyway the plan is"),
            TranscriptPiece(start: 40.0, end: 41.5, text: "okay who wants coffee"),
        ]
        let utterances = assemble(pieces)
        XCTAssertEqual(utterances.count, 2)
        XCTAssertEqual(utterances.last.map { offset($0.startedAt) } ?? -1, 40.0, accuracy: 0.01)
        XCTAssertEqual(utterances.last.map { offset($0.endedAt) } ?? -1, 41.5, accuracy: 0.01)
    }

    func testWordsArePreservedInOrder() {
        let pieces = [
            TranscriptPiece(start: 0.0, end: 0.8, text: "Remind me to"),
            TranscriptPiece(start: 0.8, end: 1.6, text: "book the dentist."),
            TranscriptPiece(start: 1.7, end: 2.4, text: "Also, parking spot"),
            TranscriptPiece(start: 2.4, end: 3.0, text: "is 4C!"),
            TranscriptPiece(start: 3.1, end: 4.0, text: "What time is"),
            TranscriptPiece(start: 4.0, end: 4.6, text: "the review?"),
            TranscriptPiece(start: 9.0, end: 10.0, text: "no idea"),
        ]
        let utterances = assemble(pieces)
        XCTAssertFalse(utterances.isEmpty)
        XCTAssertLessThan(utterances.count, pieces.count, "fragments are merged")
        XCTAssertEqual(words(utterances.map { $0.text }), words(pieces.map { $0.text }))
    }

    func testUtterancesCarrySegmentAndStayWithinItsTimeRange() {
        let pieces = [
            TranscriptPiece(start: 2.0, end: 3.0, text: "First thought."),
            TranscriptPiece(start: 3.2, end: 4.5, text: "Second thought, a bit longer."),
            TranscriptPiece(start: 30.0, end: 31.0, text: "Much later"),
        ]
        let utterances = assemble(pieces, segmentID: "seg-xyz")
        XCTAssertFalse(utterances.isEmpty)

        for utterance in utterances {
            XCTAssertEqual(utterance.segmentID, "seg-xyz")
            XCTAssertFalse(utterance.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertLessThanOrEqual(utterance.startedAt, utterance.endedAt)
            XCTAssertGreaterThanOrEqual(offset(utterance.startedAt), 2.0 - 0.01)
            XCTAssertLessThanOrEqual(offset(utterance.endedAt), 31.0 + 0.01)
        }
        for (earlier, later) in zip(utterances, utterances.dropFirst()) {
            XCTAssertLessThanOrEqual(earlier.startedAt, later.startedAt, "chronological order")
        }
    }

    func testSingleSentenceKeepsItsTiming() throws {
        let pieces = [TranscriptPiece(start: 5.0, end: 7.5, text: "The door code is 4512.")]
        let utterances = assemble(pieces)
        XCTAssertEqual(utterances.count, 1)
        let only = try XCTUnwrap(utterances.first)
        XCTAssertEqual(collapsed(only.text), "The door code is 4512.")
        XCTAssertEqual(offset(only.startedAt), 5.0, accuracy: 0.01)
        XCTAssertEqual(offset(only.endedAt), 7.5, accuracy: 0.01)
    }
}
