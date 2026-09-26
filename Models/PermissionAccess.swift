import AVFoundation

/// Screen capture and Accessibility expose only a granted/not-granted check.
/// Microphone access additionally distinguishes a first request from a denial.
enum PermissionAccessStatus: Equatable {
    case granted, notRequested, denied, restricted, notGranted

    var label: String {
        switch self {
        case .granted: return NSLocalizedString("Granted", comment: "Permission status")
        case .notRequested: return NSLocalizedString("Not requested", comment: "Permission status")
        case .denied: return NSLocalizedString("Denied", comment: "Permission status")
        case .restricted: return NSLocalizedString("Restricted", comment: "Permission status")
        case .notGranted: return NSLocalizedString("Not granted", comment: "Permission status")
        }
    }

    static func microphone(_ status: AVAuthorizationStatus) -> Self {
        switch status {
        case .authorized: return .granted
        case .notDetermined: return .notRequested
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .notGranted
        }
    }
}

struct PermissionSnapshot {
    var microphone: PermissionAccessStatus
    var accessibility: Bool
    var screenRecording: Bool

    func missingPermission(for feature: PermissionFeature) -> String? {
        switch feature {
        case .speechPlayback: return nil
        case .microphoneRecording:
            return microphone == .granted ? nil : NSLocalizedString("Microphone access is needed to record speech. You can still use text to speech without it.", comment: "Recording permission guidance")
        case .systemAudioRecording:
            return screenRecording ? nil : NSLocalizedString("Screen Recording access is needed to capture system or app audio.", comment: "Audio capture permission guidance")
        case .ocr:
            return screenRecording ? nil : NSLocalizedString("Screen Recording access is needed to capture text with OCR.", comment: "OCR permission guidance")
        case .textInsertion:
            return accessibility ? nil : NSLocalizedString("Accessibility access is needed to insert text into another app. You can still copy and paste manually.", comment: "Text insertion permission guidance")
        }
    }
}

enum PermissionFeature {
    case speechPlayback, microphoneRecording, systemAudioRecording, ocr, textInsertion
}
