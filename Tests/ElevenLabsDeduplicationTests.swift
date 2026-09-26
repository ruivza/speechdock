import XCTest
@testable import SpeechDock

/// Tests for ElevenLabs STT text deduplication logic
final class ElevenLabsDeduplicationTests: XCTestCase {

    // MARK: - Deduplication Logic Tests

    /// Simulates the deduplication logic from ElevenLabsRealtimeSTT.
    /// Deduplication compares only against the most recent committed segment,
    /// so genuinely re-spoken phrases (e.g. "はい") are not discarded.
    private func applyDeduplication(committedText: inout String, lastSegment: inout String, newText: String) {
        if committedText.isEmpty {
            committedText = newText
            lastSegment = newText
        } else if newText == lastSegment || lastSegment.hasSuffix(newText) {
            // skip duplicate
        } else {
            committedText += " " + newText
            lastSegment = newText
        }
    }

    func testEmptyCommittedText() {
        var committedText = ""
        var lastSegment = ""
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "Hello world")

        XCTAssertEqual(committedText, "Hello world")
    }

    func testAppendNewText() {
        var committedText = "Hello"
        var lastSegment = "Hello"
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "world")

        XCTAssertEqual(committedText, "Hello world")
    }

    func testSkipDuplicateSuffix() {
        // When the new text is the same as the end of committed text
        var committedText = "Hello world"
        var lastSegment = "world"
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "world")

        // Should not append duplicate
        XCTAssertEqual(committedText, "Hello world")
    }

    func testAppendRespokenPhrase() {
        // A phrase contained earlier in the history is legitimately re-spoken.
        // The old whole-history `contains` check wrongly discarded this;
        // comparing only against the last segment appends it correctly.
        var committedText = "Hello world today"
        var lastSegment = "today"
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "world")

        XCTAssertEqual(committedText, "Hello world today world")
    }

    func testSkipExactDuplicate() {
        // When the last committed segment is sent again
        var committedText = "Hello world"
        var lastSegment = "Hello world"
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "Hello world")

        // Should not append duplicate
        XCTAssertEqual(committedText, "Hello world")
    }

    func testAppendDifferentText() {
        // When new text is genuinely different
        var committedText = "Hello"
        var lastSegment = "Hello"
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "Goodbye")

        XCTAssertEqual(committedText, "Hello Goodbye")
    }

    func testPartialOverlapNotDuplicate() {
        // When new text partially overlaps but isn't contained
        var committedText = "Hello world"
        var lastSegment = "world"
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "world again")

        // "world again" is not equal to the last segment "world"
        // and "world" does not have "world again" as a suffix,
        // so this should be appended
        XCTAssertEqual(committedText, "Hello world world again")
    }

    func testCaseSensitiveComparison() {
        // Deduplication should be case-sensitive
        var committedText = "Hello World"
        var lastSegment = "Hello World"
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "world")

        // "world" != "World", so it should be appended
        XCTAssertEqual(committedText, "Hello World world")
    }

    func testMultipleSequentialAppends() {
        var committedText = ""
        var lastSegment = ""

        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "First")
        XCTAssertEqual(committedText, "First")

        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "Second")
        XCTAssertEqual(committedText, "First Second")

        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "Third")
        XCTAssertEqual(committedText, "First Second Third")
    }

    func testDuplicateAfterMultipleAppends() {
        var committedText = ""
        var lastSegment = ""

        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "Hello")
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "world")
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "world")  // duplicate

        // Should not double-append "world"
        XCTAssertEqual(committedText, "Hello world")
    }

    // MARK: - Edge Cases

    func testEmptyNewText() {
        // Empty new text should be handled before this logic in the actual code
        // In ElevenLabsRealtimeSTT, empty text is filtered with: if let text = ..., !text.isEmpty
        // This test verifies Swift's String.hasSuffix behavior with empty strings
        let lastSegment = "Hello"

        // Swift's String.hasSuffix("") returns true, so even if an empty string
        // reached the deduplication logic it would be skipped as a "duplicate".
        // The actual code also filters empty text beforehand, so this is safe.
        XCTAssertTrue(lastSegment.hasSuffix(""))
    }

    func testWhitespaceHandling() {
        var committedText = "Hello"
        var lastSegment = "Hello"
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: " ")

        // The new text is " " (single space)
        // " " != "Hello" and "Hello".hasSuffix(" ") is false
        // So we append: "Hello" + " " + " " = "Hello  "
        XCTAssertEqual(committedText, "Hello  ")
    }

    func testJapaneseText() {
        var committedText = ""
        var lastSegment = ""

        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "こんにちは")
        XCTAssertEqual(committedText, "こんにちは")

        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "世界")
        XCTAssertEqual(committedText, "こんにちは 世界")

        // Duplicate should be skipped
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "世界")
        XCTAssertEqual(committedText, "こんにちは 世界")
    }

    func testRespokenJapanesePhraseNotDiscarded() {
        // Regression test: a short phrase committed earlier in the session
        // (e.g. "はい") must not be discarded when genuinely spoken again
        var committedText = ""
        var lastSegment = ""

        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "はい")
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "次に進みます")
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "はい")

        XCTAssertEqual(committedText, "はい 次に進みます はい")
    }

    func testMixedLanguageText() {
        var committedText = "Hello"
        var lastSegment = "Hello"

        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "世界")
        XCTAssertEqual(committedText, "Hello 世界")

        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "again")
        XCTAssertEqual(committedText, "Hello 世界 again")
    }

    func testLongTextDeduplication() {
        let longText = String(repeating: "word ", count: 100).trimmingCharacters(in: .whitespaces)
        var committedText = longText
        var lastSegment = longText

        // Trying to append the same long text should skip
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: longText)
        XCTAssertEqual(committedText, longText)
    }

    // MARK: - Real-World Scenarios

    func testRealisticElevenLabsBehavior() {
        // Simulate a realistic ElevenLabs streaming session
        var committedText = ""
        var lastSegment = ""

        // First committed transcript
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "Today we're going to discuss")
        XCTAssertEqual(committedText, "Today we're going to discuss")

        // Second committed transcript (new content)
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "the importance of testing")
        XCTAssertEqual(committedText, "Today we're going to discuss the importance of testing")

        // ElevenLabs sometimes resends the last committed segment
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "the importance of testing")
        // Should be skipped (matches last segment)
        XCTAssertEqual(committedText, "Today we're going to discuss the importance of testing")

        // New content continues
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "in software development")
        XCTAssertEqual(committedText, "Today we're going to discuss the importance of testing in software development")

        // A phrase from earlier in the session is legitimately re-spoken.
        // The old whole-history check would have discarded this; it is now appended.
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "Today we're going to discuss")
        XCTAssertEqual(committedText, "Today we're going to discuss the importance of testing in software development Today we're going to discuss")
    }

    func testPartialResend() {
        // When ElevenLabs resends just the tail of the last segment
        var committedText = "Testing is important"
        var lastSegment = "Testing is important"

        // Resend of suffix
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "important")
        XCTAssertEqual(committedText, "Testing is important")  // No change

        // New content
        applyDeduplication(committedText: &committedText, lastSegment: &lastSegment, newText: "for quality")
        XCTAssertEqual(committedText, "Testing is important for quality")
    }
}
