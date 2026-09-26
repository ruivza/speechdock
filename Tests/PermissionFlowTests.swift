import AVFoundation
import XCTest
@testable import SpeechDock

@MainActor
final class PermissionFlowTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "SpeechDockPermissionTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    func testLaterPersistsAcrossServiceInstancesWithoutGrantingPermissions() {
        let defaults = defaults()
        let missing = PermissionSnapshot(microphone: .notRequested, accessibility: false, screenRecording: false)
        let service = PermissionService(defaults: defaults, readPermissions: { missing })
        XCTAssertTrue(service.shouldShowSetupOnLaunch)
        service.completeSetup()
        let relaunched = PermissionService(defaults: defaults, readPermissions: { missing })
        XCTAssertFalse(relaunched.shouldShowSetupOnLaunch)
        XCTAssertTrue(relaunched.hasAnyMissing)
        XCTAssertFalse(relaunched.microphoneGranted)
    }

    func testPlaybackNeedsNoPermissionAndRecordingUsesOnlyItsSourcePermission() {
        var snapshot = PermissionSnapshot(microphone: .denied, accessibility: false, screenRecording: true)
        XCTAssertNil(snapshot.missingPermission(for: .speechPlayback))
        XCTAssertNil(snapshot.missingPermission(for: .systemAudioRecording))
        XCTAssertNil(snapshot.missingPermission(for: .ocr))
        XCTAssertNotNil(snapshot.missingPermission(for: .microphoneRecording))
        XCTAssertNotNil(snapshot.missingPermission(for: .textInsertion))
        snapshot.microphone = .granted
        snapshot.screenRecording = false
        XCTAssertNil(snapshot.missingPermission(for: .microphoneRecording))
        XCTAssertNotNil(snapshot.missingPermission(for: .systemAudioRecording))
        XCTAssertNotNil(snapshot.missingPermission(for: .ocr))
    }

    func testDeferredSetupStillGuidesAtFeatureUseAndRefreshesChangedPermissions() {
        var snapshot = PermissionSnapshot(microphone: .notRequested, accessibility: false, screenRecording: false)
        let service = PermissionService(defaults: defaults(), readPermissions: { snapshot })
        service.completeSetup()
        var messages = [String]()
        XCTAssertTrue(service.ensureAccess(for: .speechPlayback, showSetup: { messages.append($0) }))
        XCTAssertTrue(messages.isEmpty)
        for feature in [PermissionFeature.microphoneRecording, .systemAudioRecording, .ocr, .textInsertion] {
            XCTAssertFalse(service.ensureAccess(for: feature, showSetup: { messages.append($0) }))
        }
        XCTAssertEqual(messages.count, 4)
        snapshot.microphone = .granted
        XCTAssertTrue(service.ensureAccess(for: .microphoneRecording, showSetup: { messages.append($0) }))
        XCTAssertEqual(messages.count, 4)
    }

    func testMicrophoneStatusesDistinguishUnrequestedDeniedRestrictedAndGranted() {
        XCTAssertEqual(PermissionAccessStatus.microphone(.notDetermined), .notRequested)
        XCTAssertEqual(PermissionAccessStatus.microphone(.denied), .denied)
        XCTAssertEqual(PermissionAccessStatus.microphone(.restricted), .restricted)
        XCTAssertEqual(PermissionAccessStatus.microphone(.authorized), .granted)
    }

    func testAllGrantedDoesNotOfferSetup() {
        let service = PermissionService(defaults: defaults(), readPermissions: {
            PermissionSnapshot(microphone: .granted, accessibility: true, screenRecording: true)
        })
        XCTAssertFalse(service.shouldShowSetupOnLaunch)
    }
}
