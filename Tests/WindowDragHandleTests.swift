import AppKit
import XCTest
@testable import SpeechDock

@MainActor
final class WindowDragHandleTests: XCTestCase {
    private final class DragWindow: NSWindow {
        var dragEvent: NSEvent?
        override func performDrag(with event: NSEvent) { dragEvent = event }
    }

    func testDragForwardsOriginalEventWithoutChangingTextFocus() {
        let window = DragWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                                styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let handle = WindowDragHandleView(frame: NSRect(x: 20, y: 184, width: 360, height: 12))
        let editor = NSTextView(frame: NSRect(x: 20, y: 20, width: 360, height: 140))
        window.contentView?.addSubview(editor)
        window.contentView?.addSubview(handle)
        window.makeFirstResponder(editor)
        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 200, y: 190),
                                      modifierFlags: [], timestamp: 1, windowNumber: window.windowNumber,
                                      context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
        handle.mouseDown(with: event)
        XCTAssertTrue(window.dragEvent === event)
        XCTAssertTrue(window.firstResponder === editor)
        XCTAssertTrue(handle.acceptsFirstMouse(for: event))
    }

    func testHandleLeavesEditorAndResizeEdgeHitTargetsUnchanged() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        let editor = NSTextView(frame: NSRect(x: 20, y: 20, width: 360, height: 140))
        let handle = WindowDragHandleView(frame: NSRect(x: 20, y: 184, width: 360, height: 12))
        container.addSubview(editor)
        container.addSubview(handle)
        XCTAssertTrue(container.hitTest(NSPoint(x: 200, y: 190)) === handle)
        XCTAssertTrue(container.hitTest(NSPoint(x: 200, y: 100)) === editor)
        XCTAssertTrue(container.hitTest(NSPoint(x: 200, y: 199)) === container)
        XCTAssertTrue(container.hitTest(NSPoint(x: 1, y: 190)) === container)
    }

    func testNonmovableWindowDoesNotStartDrag() {
        let window = DragWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isMovable = false
        let handle = WindowDragHandleView()
        window.contentView = handle
        let event = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero, modifierFlags: [],
                                      timestamp: 1, windowNumber: window.windowNumber, context: nil,
                                      eventNumber: 1, clickCount: 1, pressure: 1)!
        handle.mouseDown(with: event)
        XCTAssertNil(window.dragEvent)
    }
}
