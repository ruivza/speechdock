import AppKit
import AVFoundation
import ApplicationServices

/// Reactive permission monitoring service.
/// Monitors Microphone, Accessibility, and Screen Recording permissions
/// and updates state in real-time via polling and system notifications.
@Observable
@MainActor
final class PermissionService {
    static let shared = PermissionService()

    // MARK: - Permission State

    private(set) var snapshot = PermissionSnapshot(microphone: .notRequested, accessibility: false, screenRecording: false)
    var microphoneGranted: Bool { snapshot.microphone == .granted }
    var accessibilityGranted: Bool { snapshot.accessibility }
    var screenRecordingGranted: Bool { snapshot.screenRecording }
    var microphoneStatus: PermissionAccessStatus { snapshot.microphone }

    private let defaults: UserDefaults
    private let readPermissions: () -> PermissionSnapshot
    private static let setupCompletedKey = "permissionSetupCompleted"
    var shouldShowSetupOnLaunch: Bool { hasAnyMissing && !defaults.bool(forKey: Self.setupCompletedKey) }

    func completeSetup() {
        defaults.set(true, forKey: Self.setupCompletedKey)
    }

    /// Called at feature entry points; dismissing setup never grants access.
    @discardableResult
    func ensureAccess(for feature: PermissionFeature,
                      showSetup: ((String) -> Void)? = nil) -> Bool {
        refreshAllPermissions()
        guard let reason = snapshot.missingPermission(for: feature) else { return true }
        if let showSetup { showSetup(reason) }
        else { PermissionSetupController.shared.show(reason: reason) }
        return false
    }

    /// All permissions are granted
    var allGranted: Bool { microphoneGranted && accessibilityGranted && screenRecordingGranted }

    /// Whether any permission is missing
    var hasAnyMissing: Bool { !allGranted }

    // MARK: - Monitoring State

    private var pollingTask: Task<Void, Never>?
    private var notificationObserver: NSObjectProtocol?
    private(set) var isMonitoring = false

    // MARK: - Init

    init(defaults: UserDefaults = .standard, readPermissions: @escaping () -> PermissionSnapshot = {
        PermissionSnapshot(microphone: .microphone(AVCaptureDevice.authorizationStatus(for: .audio)),
                           accessibility: AXIsProcessTrusted(), screenRecording: CGPreflightScreenCaptureAccess())
    }) {
        self.defaults = defaults
        self.readPermissions = readPermissions
        refreshAllPermissions()
    }

    // MARK: - Permission Checking

    /// Refresh all permission states immediately
    func refreshAllPermissions() {
        snapshot = readPermissions()
    }

    // MARK: - Monitoring

    /// Start monitoring permission changes via polling and system notifications.
    /// Call when the permission setup window is shown.
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        refreshAllPermissions()
        startPolling()
        startActivationListener()
        dprint("PermissionService: Started monitoring")

    }

    /// Stop monitoring permission changes.
    /// Call when the permission setup window is closed.
    func stopMonitoring() {
        isMonitoring = false

        pollingTask?.cancel()
        pollingTask = nil

        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
        dprint("PermissionService: Stopped monitoring")

    }

    /// Polling loop with adaptive intervals.
    /// Fast polling (0.5s) for the first 10 seconds, then slower (2s).
    /// Continues while the setup window is open, including after a revocation.
    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            var elapsedSeconds: Double = 0

            while !Task.isCancelled {
                let interval: Double = elapsedSeconds < 10 ? 0.5 : 2.0
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))

                guard !Task.isCancelled else { break }

                self?.refreshAllPermissions()

                elapsedSeconds += interval

            }
        }
    }

    /// Recheck on return from System Settings using a public AppKit notification.
    private func startActivationListener() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            // Delay slightly to allow TCC database to update
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 250_000_000) // 250ms
                self?.refreshAllPermissions()
            }
        }
    }

    // MARK: - Permission Requests

    /// Request microphone permission via system dialog.
    /// Returns true if permission was granted.
    @discardableResult
    func requestMicrophone() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            refreshAllPermissions()
            return granted
        }
        return status == .authorized
    }

    // MARK: - Open System Settings

    func openMicrophoneSettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    func openAccessibilitySettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    func openScreenRecordingSettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private func openSystemSettings(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
