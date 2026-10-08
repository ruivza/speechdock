import AppKit
import AVFoundation
import ScreenCaptureKit

/// Reactive permission monitoring service.
/// Monitors Microphone and Screen Recording permissions
/// and updates state in real-time via polling and system notifications.
@Observable
@MainActor
final class PermissionService {
    static let shared = PermissionService()

    // MARK: - Permission State

    private(set) var snapshot = PermissionSnapshot(microphone: .notRequested, screenRecording: false)
    var microphoneGranted: Bool { snapshot.microphone == .granted }
    var screenRecordingGranted: Bool { snapshot.screenRecording }
    var microphoneStatus: PermissionAccessStatus { snapshot.microphone }

    private let defaults: UserDefaults
    private let readPermissions: () -> PermissionSnapshot
    private let requestMicrophoneAccess: () async -> Bool
    private let verifyScreenRecording: () async -> Bool
    private var verifiedScreenRecording: Bool?
    private var screenVerificationGeneration = 0
    private var verifyScreenOnActivation = false
    private(set) var isCheckingScreenRecording = false
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
    var allGranted: Bool { microphoneGranted && screenRecordingGranted }

    /// Whether any permission is missing
    var hasAnyMissing: Bool { !allGranted }

    // MARK: - Monitoring State

    private var pollingTask: Task<Void, Never>?
    private var notificationObserver: NSObjectProtocol?
    private(set) var isMonitoring = false

    // MARK: - Init

    init(defaults: UserDefaults = .standard, readPermissions: @escaping () -> PermissionSnapshot = {
        PermissionSnapshot(microphone: .microphone(AVCaptureDevice.authorizationStatus(for: .audio)),
                           screenRecording: CGPreflightScreenCaptureAccess())
    }, requestMicrophoneAccess: @escaping () async -> Bool = {
        await AVCaptureDevice.requestAccess(for: .audio)
    }, verifyScreenRecording: @escaping () async -> Bool = {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            return !content.displays.isEmpty
        } catch { return false }
    }) {
        self.defaults = defaults
        self.readPermissions = readPermissions
        self.requestMicrophoneAccess = requestMicrophoneAccess
        self.verifyScreenRecording = verifyScreenRecording
        refreshAllPermissions()
    }

    // MARK: - Permission Checking

    /// Refresh all permission states immediately
    func refreshAllPermissions() {
        snapshot = readPermissions()
        // A successful ScreenCaptureKit check is authoritative even when the
        // legacy preflight is stale. Feature entry always performs a fresh check.
        if let verifiedScreenRecording { snapshot.screenRecording = verifiedScreenRecording }
    }

    @discardableResult
    func refreshScreenRecordingPermission() async -> Bool {
        screenVerificationGeneration += 1
        let generation = screenVerificationGeneration
        isCheckingScreenRecording = true
        let granted = await verifyScreenRecording()
        guard generation == screenVerificationGeneration else { return false }
        isCheckingScreenRecording = false
        guard !Task.isCancelled else { return false }
        verifiedScreenRecording = granted
        refreshAllPermissions()
        return granted
    }

    /// Call only after a capture action or an explicit permission recheck.
    func ensureScreenRecordingAccess(for feature: PermissionFeature,
                                     showSetup: ((String) -> Void)? = nil) async -> Bool {
        let expectedGeneration = screenVerificationGeneration + 1
        let granted = await refreshScreenRecordingPermission()
        guard expectedGeneration == screenVerificationGeneration, !Task.isCancelled else { return false }
        guard granted else {
            let reason = NSLocalizedString("Screen capture is unavailable in this session. Check permissions for this app, then restart it if needed.", comment: "Screen capture permission guidance")
            if let showSetup { showSetup(reason) }
            else { PermissionSetupController.shared.show(reason: reason) }
            return false
        }
        return true
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
                guard let self, self.isMonitoring else { return }
                self.refreshAllPermissions()
                if self.verifyScreenOnActivation || self.verifiedScreenRecording != nil {
                    self.verifyScreenOnActivation = false
                    await self.refreshScreenRecordingPermission()
                }
            }
        }
    }

    // MARK: - Permission Requests

    /// Request microphone permission via system dialog.
    /// Returns true if permission was granted.
    @discardableResult
    func requestMicrophone() async -> Bool {
        refreshAllPermissions()
        if microphoneStatus == .notRequested {
            _ = await requestMicrophoneAccess()
        }
        refreshAllPermissions()
        return microphoneGranted
    }

    // MARK: - Open System Settings

    func openMicrophoneSettings() {
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    func openScreenRecordingSettings() {
        verifyScreenOnActivation = true
        openSystemSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private func openSystemSettings(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
