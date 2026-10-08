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
        let missing = PermissionSnapshot(microphone: .notRequested, screenRecording: false)
        let service = PermissionService(defaults: defaults, readPermissions: { missing })
        XCTAssertTrue(service.shouldShowSetupOnLaunch)
        service.completeSetup()
        let relaunched = PermissionService(defaults: defaults, readPermissions: { missing })
        XCTAssertFalse(relaunched.shouldShowSetupOnLaunch)
        XCTAssertTrue(relaunched.hasAnyMissing)
        XCTAssertFalse(relaunched.microphoneGranted)
    }

    func testPlaybackNeedsNoPermissionAndRecordingUsesOnlyItsSourcePermission() {
        var snapshot = PermissionSnapshot(microphone: .denied, screenRecording: true)
        XCTAssertNil(snapshot.missingPermission(for: .speechPlayback))
        XCTAssertNil(snapshot.missingPermission(for: .systemAudioRecording))
        XCTAssertNil(snapshot.missingPermission(for: .ocr))
        XCTAssertNotNil(snapshot.missingPermission(for: .microphoneRecording))
        snapshot.microphone = .granted
        snapshot.screenRecording = false
        XCTAssertNil(snapshot.missingPermission(for: .microphoneRecording))
        XCTAssertNotNil(snapshot.missingPermission(for: .systemAudioRecording))
        XCTAssertNotNil(snapshot.missingPermission(for: .ocr))
    }

    func testDeferredSetupStillGuidesAtFeatureUseAndRefreshesChangedPermissions() {
        var snapshot = PermissionSnapshot(microphone: .notRequested, screenRecording: false)
        let service = PermissionService(defaults: defaults(), readPermissions: { snapshot })
        service.completeSetup()
        var messages = [String]()
        XCTAssertTrue(service.ensureAccess(for: .speechPlayback, showSetup: { messages.append($0) }))
        XCTAssertTrue(messages.isEmpty)
        for feature in [PermissionFeature.microphoneRecording, .systemAudioRecording, .ocr] {
            XCTAssertFalse(service.ensureAccess(for: feature, showSetup: { messages.append($0) }))
        }
        XCTAssertEqual(messages.count, 3)
        snapshot.microphone = .granted
        XCTAssertTrue(service.ensureAccess(for: .microphoneRecording, showSetup: { messages.append($0) }))
        XCTAssertEqual(messages.count, 3)
    }

    func testMicrophoneStatusesDistinguishUnrequestedDeniedRestrictedAndGranted() {
        XCTAssertEqual(PermissionAccessStatus.microphone(.notDetermined), .notRequested)
        XCTAssertEqual(PermissionAccessStatus.microphone(.denied), .denied)
        XCTAssertEqual(PermissionAccessStatus.microphone(.restricted), .restricted)
        XCTAssertEqual(PermissionAccessStatus.microphone(.authorized), .granted)
    }

    func testAllGrantedDoesNotOfferSetup() {
        let service = PermissionService(defaults: defaults(), readPermissions: {
            PermissionSnapshot(microphone: .granted, screenRecording: true)
        })
        XCTAssertFalse(service.shouldShowSetupOnLaunch)
    }

    func testAlreadyAuthorizedMicrophoneRefreshesWithoutRequestingAgain() async {
        var state = PermissionSnapshot(microphone: .denied, screenRecording: false)
        var requests = 0
        let service = PermissionService(defaults: defaults(), readPermissions: { state }, requestMicrophoneAccess: {
            requests += 1
            return false
        })
        state.microphone = .granted
        let granted = await service.requestMicrophone()
        XCTAssertTrue(granted)
        XCTAssertTrue(service.microphoneGranted)
        XCTAssertEqual(requests, 0)
    }

    func testMicrophoneRequestRefreshesBothGrantedAndDeniedResults() async {
        for grant in [true, false] {
            var state = PermissionSnapshot(microphone: .notRequested, screenRecording: false)
            let service = PermissionService(defaults: defaults(), readPermissions: { state }, requestMicrophoneAccess: {
                state.microphone = grant ? .granted : .denied
                return grant
            })
            let result = await service.requestMicrophone()
            XCTAssertEqual(result, grant)
            XCTAssertEqual(service.microphoneGranted, grant)
        }
    }

    func testScreenCaptureProofOverridesStalePreflightAndRechecksRevocation() async {
        var actualAccess = true
        var checks = 0
        let service = PermissionService(defaults: defaults(), readPermissions: {
            PermissionSnapshot(microphone: .denied, screenRecording: false)
        }, verifyScreenRecording: { checks += 1; return actualAccess })
        service.refreshAllPermissions()
        XCTAssertEqual(checks, 0, "Launch and passive polling must not request screen access")
        var messages: [String] = []
        let initiallyGranted = await service.ensureScreenRecordingAccess(for: .ocr, showSetup: { messages.append($0) })
        XCTAssertTrue(initiallyGranted)
        service.refreshAllPermissions()
        XCTAssertTrue(service.screenRecordingGranted)
        XCTAssertFalse(service.microphoneGranted, "Screen access cannot grant microphone access")
        actualAccess = false
        let afterRevocation = await service.ensureScreenRecordingAccess(for: .systemAudioRecording, showSetup: { messages.append($0) })
        XCTAssertFalse(afterRevocation)
        XCTAssertFalse(service.screenRecordingGranted)
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(checks, 2)
    }

    func testOlderScreenCheckCannotOverwriteNewerResult() async {
        var replies: [CheckedContinuation<Bool, Never>] = []
        let service = PermissionService(defaults: defaults(), readPermissions: {
            PermissionSnapshot(microphone: .granted, screenRecording: false)
        }, verifyScreenRecording: {
            await withCheckedContinuation { replies.append($0) }
        })
        let older = Task { await service.refreshScreenRecordingPermission() }
        while replies.count < 1 { await Task.yield() }
        let newer = Task { await service.refreshScreenRecordingPermission() }
        while replies.count < 2 { await Task.yield() }
        replies[1].resume(returning: false)
        _ = await newer.value
        replies[0].resume(returning: true)
        _ = await older.value
        XCTAssertFalse(service.screenRecordingGranted)
        XCTAssertFalse(service.isCheckingScreenRecording)
    }

    func testCancelledScreenCheckCannotGrantOrShowSetup() async {
        var reply: CheckedContinuation<Bool, Never>?
        let service = PermissionService(defaults: defaults(), readPermissions: {
            PermissionSnapshot(microphone: .granted, screenRecording: false)
        }, verifyScreenRecording: { await withCheckedContinuation { reply = $0 } })
        var messages: [String] = []
        let check = Task { await service.ensureScreenRecordingAccess(for: .ocr, showSetup: { messages.append($0) }) }
        while reply == nil { await Task.yield() }
        check.cancel()
        reply?.resume(returning: true)
        let result = await check.value
        XCTAssertFalse(result)
        XCTAssertFalse(service.screenRecordingGranted)
        XCTAssertTrue(messages.isEmpty)
        XCTAssertFalse(service.isCheckingScreenRecording)
    }

    func testSupersededFeatureCheckDoesNotShowAnObsoletePermissionWarning() async {
        var replies: [CheckedContinuation<Bool, Never>] = []
        let service = PermissionService(defaults: defaults(), readPermissions: {
            PermissionSnapshot(microphone: .granted, screenRecording: false)
        }, verifyScreenRecording: { await withCheckedContinuation { replies.append($0) } })
        var messages: [String] = []
        let feature = Task { await service.ensureScreenRecordingAccess(for: .ocr, showSetup: { messages.append($0) }) }
        while replies.count < 1 { await Task.yield() }
        let recheck = Task { await service.refreshScreenRecordingPermission() }
        while replies.count < 2 { await Task.yield() }
        replies[1].resume(returning: true)
        _ = await recheck.value
        replies[0].resume(returning: false)
        _ = await feature.value
        XCTAssertTrue(service.screenRecordingGranted)
        XCTAssertTrue(messages.isEmpty)
    }
}
