import AppKit
import XCTest
@testable import SpeechDock

@MainActor
final class ClipboardTextReaderTests: XCTestCase {
    func testReadingCopiedTextPreservesClipboardContents() {
        let pasteboard = NSPasteboard(name: .init("SpeechDockClipboardTest." + UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("First paragraph 😀\n\nSecond paragraph", forType: .string)
        let count = pasteboard.changeCount
        XCTAssertEqual(ClipboardTextReader.shared.readBestTextFromPasteboard(pasteboard),
                       "First paragraph 😀\n\nSecond paragraph")
        XCTAssertEqual(pasteboard.changeCount, count)
        XCTAssertEqual(pasteboard.string(forType: .string), "First paragraph 😀\n\nSecond paragraph")
    }

    func testReadingEmptyClipboardDoesNotInventSelectedText() {
        let pasteboard = NSPasteboard(name: .init("SpeechDockClipboardTest." + UUID().uuidString))
        defer { pasteboard.releaseGlobally() }
        XCTAssertNil(ClipboardTextReader.shared.readBestTextFromPasteboard(pasteboard))
    }
}
