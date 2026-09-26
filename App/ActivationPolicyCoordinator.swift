import AppKit

/// Tracks user-facing windows; auxiliary overlays never register here.
@MainActor
final class ActivationPolicyCoordinator {
    static let shared = ActivationPolicyCoordinator { NSApp.setActivationPolicy($0) }

    private let windows = NSHashTable<NSWindow>.weakObjects()
    private let applyPolicy: (NSApplication.ActivationPolicy) -> Void

    init(applyPolicy: @escaping (NSApplication.ActivationPolicy) -> Void) {
        self.applyPolicy = applyPolicy
    }

    func windowWillShow(_ window: NSWindow) {
        windows.add(window)
        updatePolicy()
    }

    func windowDidHide(_ window: NSWindow) {
        windows.remove(window)
        updatePolicy()
    }

    func updatePolicy() {
        applyPolicy(windows.allObjects.isEmpty ? .accessory : .regular)
    }
}
