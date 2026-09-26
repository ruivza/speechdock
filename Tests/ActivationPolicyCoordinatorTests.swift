import AppKit
import XCTest
@testable import SpeechDock

@MainActor
final class ActivationPolicyCoordinatorTests: XCTestCase {
    func testEveryOpeningAndClosingOrderKeepsDockUntilLastWindowCloses() {
        let orders = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
        for opening in orders {
            for closing in orders {
                var policy: NSApplication.ActivationPolicy = .prohibited
                let coordinator = ActivationPolicyCoordinator { policy = $0 }
                let windows = (0..<3).map { _ in NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false) }
                windows.forEach { $0.isReleasedWhenClosed = false }
                coordinator.updatePolicy()
                XCTAssertEqual(policy, .accessory)
                for index in opening {
                    coordinator.windowWillShow(windows[index])
                    XCTAssertEqual(policy, .regular)
                }
                for (offset, index) in closing.enumerated() {
                    coordinator.windowDidHide(windows[index])
                    XCTAssertEqual(policy, offset == 2 ? .accessory : .regular)
                }
            }
        }
    }

    func testPermissionWindowAndPanelKeepDockInBothClosingOrders() async {
        _ = NSApplication.shared
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "permissionSetupCompleted")
        defer {
            if let saved { defaults.set(saved, forKey: "permissionSetupCompleted") }
            else { defaults.removeObject(forKey: "permissionSetupCompleted") }
        }
        let app = AppState(startServices: false)
        let manager = FloatingWindowManager()
        for closePermissionFirst in [true, false] {
            PermissionSetupController.shared.show()
            manager.showTTSFloatingWindow(appState: app, onClose: {})
            XCTAssertEqual(NSApp.activationPolicy(), .regular)
            if closePermissionFirst {
                PermissionSetupController.shared.dismiss()
                XCTAssertEqual(NSApp.activationPolicy(), .regular)
                manager.hideFloatingWindow(skipActivation: true)
            } else {
                manager.hideFloatingWindow(skipActivation: true)
                XCTAssertEqual(NSApp.activationPolicy(), .regular)
                PermissionSetupController.shared.dismiss()
            }
            XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        }
    }

    func testRepeatedShowAndLateCloseCannotUnregisterAnotherWindow() {
        var policy: NSApplication.ActivationPolicy = .prohibited
        let coordinator = ActivationPolicyCoordinator { policy = $0 }
        let old = NSWindow()
        let replacement = NSWindow()
        coordinator.windowWillShow(old)
        coordinator.windowWillShow(replacement)
        coordinator.windowWillShow(replacement)
        coordinator.windowDidHide(old)
        coordinator.windowDidHide(old)
        XCTAssertEqual(policy, .regular)
        coordinator.windowDidHide(replacement)
        XCTAssertEqual(policy, .accessory)
    }
}
