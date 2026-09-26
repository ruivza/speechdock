import AppKit
import SwiftUI

/// A dedicated AppKit drag surface: background dragging through NSHostingView
/// does not reliably reach NSWindow on macOS 27. Keep this in unused top padding,
/// away from controls, text selection, file drop targets, and resize edges.
struct WindowDragHandle: NSViewRepresentable {
    var color: NSColor = .secondaryLabelColor

    func makeNSView(context: Context) -> WindowDragHandleView {
        let view = WindowDragHandleView()
        let label = NSLocalizedString("Drag to move window", comment: "Window drag handle")
        view.toolTip = label
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.handle)
        view.setAccessibilityLabel(label)
        return view
    }

    func updateNSView(_ view: WindowDragHandleView, context: Context) {
        view.handleColor = color
    }
}

final class WindowDragHandleView: NSView {
    var handleColor: NSColor = .secondaryLabelColor {
        didSet { needsDisplay = true }
    }

    override var mouseDownCanMoveWindow: Bool { false }

    // A single drag also works when another application is active. Do not take
    // first responder from the panel's text editor.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard event.type == .leftMouseDown, let window, window.isMovable else { return }
        NSCursor.closedHand.push()
        defer { NSCursor.pop() }
        window.performDrag(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        handleColor.setFill()
        let handle = NSRect(x: bounds.midX - 16, y: bounds.midY - 1.5, width: 32, height: 3)
        NSBezierPath(roundedRect: handle, xRadius: 1.5, yRadius: 1.5).fill()
    }
}
