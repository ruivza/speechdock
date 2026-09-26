import AppKit

/// Floating tools share the standard floating level; ordering uses orderFront.
@MainActor
final class WindowLevelCoordinator {
    static let shared = WindowLevelCoordinator()
    private init() {}
    func nextPanelLevel() -> NSWindow.Level { .floating }
    func reset() {}
    static func configureSavePanel(_ panel: NSSavePanel) {
        panel.contentMinSize = NSSize(width: 500, height: 350)
    }
}
