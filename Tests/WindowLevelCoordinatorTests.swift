import AppKit
import XCTest
@testable import SpeechDock

@MainActor
final class WindowLevelCoordinatorTests: XCTestCase {
    func testRepeatedPanelPresentationDoesNotEscalateLevel() {
        for _ in 0..<110 { XCTAssertEqual(WindowLevelCoordinator.shared.nextPanelLevel(), .floating) }
    }

    func testSavePanelKeepsSystemLevelAndFitsSmallDisplay() {
        let panel = NSSavePanel()
        let systemLevel = panel.level
        WindowLevelCoordinator.configureSavePanel(panel)
        XCTAssertEqual(panel.level, systemLevel)
        XCTAssertLessThanOrEqual(panel.contentMinSize.width, 600)
        XCTAssertLessThanOrEqual(panel.contentMinSize.height, 400)
    }

    func testAlertAttachesToFloatingParent() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 400), styleMask: .titled, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.level = .floating
        let alert = NSAlert()
        alert.messageText = "Test"
        WindowPresentation.alert(alert, parent: window)
        XCTAssertEqual(alert.window.sheetParent, window)
        window.endSheet(alert.window)
        window.orderOut(nil)
    }
}
