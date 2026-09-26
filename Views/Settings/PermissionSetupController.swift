import AppKit
import SwiftUI

/// Manages the permission setup window lifecycle.
/// Follows the same pattern as WindowManager for consistency.
@MainActor
final class PermissionSetupController: NSObject, NSWindowDelegate {
    static let shared = PermissionSetupController()

    private var window: NSWindow?

    private override init() {
        super.init()
    }

    /// Show the permission setup window.
    /// Starts permission monitoring and displays the checklist.
    func show() {
        // If window already exists and is visible, just bring it to front
        if let window = window, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Start monitoring permissions
        PermissionService.shared.startMonitoring()

        // Show in Dock while permission setup is open
        NSApp.setActivationPolicy(.regular)

        let setupView = PermissionSetupView(
            onContinue: { [weak self] in
                self?.dismiss()
            },
            onLater: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingController = NSHostingController(rootView: setupView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = NSLocalizedString("SpeechDock Permissions", comment: "Permission setup window title")
        window.identifier = NSUserInterfaceItemIdentifier("permissionSetup")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 480, height: 420))
        window.center()
        window.delegate = self

        // Disable automatic key view loop to prevent Liquid Glass focus ring
        window.autorecalculatesKeyViewLoop = false

        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        // Clear first responder to remove initial focus ring
        DispatchQueue.main.async {
            window.makeFirstResponder(nil)
        }
    }

    /// Close the permission setup window and stop monitoring.
    func dismiss() {
        window?.close()
    }

    /// Whether the permission setup window is currently visible
    var isVisible: Bool {
        window?.isVisible ?? false
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        window = nil
        PermissionService.shared.stopMonitoring()
        // Only drop back to accessory when no other windows are open —
        // otherwise the Dock icon disappears while e.g. Settings is still
        // visible (same fix as FloatingWindowManager.hideFloatingWindow).
        let hasOtherWindows = NSApp.windows.contains {
            $0.identifier?.rawValue == "settings" && $0.isVisible
        }
        if !hasOtherWindows {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
