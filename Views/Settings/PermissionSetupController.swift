import AppKit
import SwiftUI

/// Manages the permission setup window lifecycle.
/// Follows the same pattern as WindowManager for consistency.
@MainActor
final class PermissionSetupController: NSObject, NSWindowDelegate {
    static let shared = PermissionSetupController()

    private var window: NSWindow?
    private let setupReason = PermissionSetupReason()

    private override init() {
        super.init()
    }

    /// Show the permission setup window.
    /// Starts permission monitoring and displays the checklist.
    func show(reason: String? = nil) {
        setupReason.message = reason

        // If window already exists and is visible, just bring it to front
        if let window = window, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        // Start monitoring permissions
        PermissionService.shared.startMonitoring()

        let setupView = PermissionSetupView(
            reason: setupReason,
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
        window.setContentSize(NSSize(width: 540, height: 530))
        window.center()
        window.delegate = self

        // Keep Tab navigation; suppress only the initial focus below.
        window.autorecalculatesKeyViewLoop = true

        self.window = window
        ActivationPolicyCoordinator.shared.windowWillShow(window)
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
        PermissionService.shared.completeSetup()
        window = nil
        PermissionService.shared.stopMonitoring()
        if let closedWindow = notification.object as? NSWindow {
            ActivationPolicyCoordinator.shared.windowDidHide(closedWindow)
        }
    }
}
