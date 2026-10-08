import AppKit
import XCTest
@testable import SpeechDock

@MainActor
final class UsabilityRegressionTests: XCTestCase {
    func testFileTranscriptionPreservesDraftAndSeparatesResult() {
        XCTAssertEqual(FileTranscriptionText.appending(" new \n", to: "draft"), "draft\nnew")
        XCTAssertEqual(FileTranscriptionText.appending("new", to: "draft\n"), "draft\nnew")
        XCTAssertEqual(FileTranscriptionText.appending("new", to: ""), "new")
        XCTAssertNil(FileTranscriptionText.appending(" \n\t", to: "draft"))
    }

    func testWindowRestoresOnSecondaryDisplayAndSurvivesDisconnect() {
        let primary = NSRect(x: 0, y: 40, width: 1200, height: 760)
        let secondary = NSRect(x: -1600, y: 0, width: 1600, height: 900)
        let saved = NSRect(x: -1000, y: 100, width: 500, height: 600)
        XCTAssertEqual(WindowPlacement.fit(saved, visibleFrames: [primary, secondary]), saved)
        XCTAssertTrue(primary.contains(WindowPlacement.fit(saved, visibleFrames: [primary])))
        let oversized = NSRect(x: 5000, y: 5000, width: 2000, height: 2000)
        XCTAssertEqual(WindowPlacement.fit(oversized, visibleFrames: [primary]), primary)
    }

    func testAudioFileFormatsAreSharedByChooserAndDropValidation() {
        for ext in AudioFileSupport.extensions {
            let url = URL(fileURLWithPath: "/example." + ext.uppercased())
            XCTAssertTrue(AudioFileSupport.accepts(url))
            XCTAssertTrue(AudioFileSupport.formatHint.contains(ext.uppercased()))
        }
        XCTAssertTrue(AudioFileSupport.accepts(URL(fileURLWithPath: "/example.AIFF")))
        XCTAssertTrue(AudioFileSupport.accepts(URL(fileURLWithPath: "/example.aif")))
        XCTAssertFalse(AudioFileSupport.accepts(URL(fileURLWithPath: "/example.txt")))
    }

    func testCaptureCoordinatesOnDisplaysAboveAndLeftOfPrimary() {
        let screen = CGRect(x: -1200, y: 900, width: 1200, height: 800)
        let region = CGRect(x: -1000, y: 1000, width: 300, height: 200)
        XCTAssertEqual(ScreenCaptureService.sourceRect(region, on: screen), CGRect(x: 200, y: 500, width: 300, height: 200))
    }

    func testToolsFollowExplicitInvocationWithoutJoiningEverySpace() {
        XCTAssertTrue(ToolWindowPolicy.currentSpace.contains(.moveToActiveSpace))
        XCTAssertTrue(ToolWindowPolicy.currentSpace.contains(.fullScreenAuxiliary))
        XCTAssertFalse(ToolWindowPolicy.currentSpace.contains(.canJoinAllSpaces))
    }

    func testAllSixBundledLocalesLoadNewGuidance() throws {
        let resources = try XCTUnwrap(Bundle(for: AppDelegate.self).resourceURL)
        for locale in ["en", "ja", "de", "fr", "ko", "zh-Hans"] {
            let bundle = try XCTUnwrap(Bundle(url: resources.appendingPathComponent(locale + ".lproj")))
            for key in ["No speech could be recognized.", "Maximum 100 MB · No duration limit", "Supported text files: %@", "Allow only the features you need. Text to speech works without microphone access."] {
                XCTAssertNotEqual(bundle.localizedString(forKey: key, value: "__missing__", table: nil), "__missing__", "Missing \(locale): \(key)")
            }
        }
    }

    func testHotKeyReportsDuplicateRegistration() {
        let first = RegisteredHotKey(keyCode: 122, modifiers: 0x1000 | 0x0800 | 0x0200 | 0x0100)
        XCTAssertEqual(first.status, 0)
        let second = RegisteredHotKey(keyCode: 122, modifiers: 0x1000 | 0x0800 | 0x0200 | 0x0100)
        XCTAssertNotEqual(second.status, 0)
        withExtendedLifetime(first) {}
    }
}
