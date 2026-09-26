import AppKit

/// Fits the entire window, including its drag handle and controls, on a connected display.
enum WindowPlacement {
    static func fit(_ frame: NSRect, visibleFrames: [NSRect]) -> NSRect {
        guard !visibleFrames.isEmpty else { return frame }
        let screen = visibleFrames.max { a, b in
            let aArea = frame.intersection(a).isNull ? 0 : frame.intersection(a).width * frame.intersection(a).height
            let bArea = frame.intersection(b).isNull ? 0 : frame.intersection(b).width * frame.intersection(b).height
            if aArea != bArea { return aArea < bArea }
            return hypot(frame.midX - a.midX, frame.midY - a.midY) > hypot(frame.midX - b.midX, frame.midY - b.midY)
        }!
        let size = NSSize(width: min(frame.width, screen.width), height: min(frame.height, screen.height))
        return NSRect(x: min(max(frame.minX, screen.minX), screen.maxX - size.width),
                      y: min(max(frame.minY, screen.minY), screen.maxY - size.height),
                      width: size.width, height: size.height)
    }

    @MainActor static func fit(_ window: NSWindow) {
        window.setFrame(fit(window.frame, visibleFrames: NSScreen.screens.map(\.visibleFrame)), display: true)
    }
}
