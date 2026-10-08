import AVFoundation
import XCTest
@testable import SpeechDock

@MainActor
final class VoiceInputSessionTests: XCTestCase {
    private final class MockSTT: RealtimeSTTService {
        weak var delegate: RealtimeSTTDelegate?
        var isListening = false
        var selectedModel = ""
        var selectedLanguage = ""
        var audioInputDeviceUID = ""
        var audioSource: STTAudioSource = .microphone
        var vadMinimumRecordingTime: TimeInterval = 0
        var vadSilenceDuration: TimeInterval = 0
        var starts = 0
        var stops = 0
        var finishes = 0
        var startBarrier: CheckedContinuation<Void, Never>?
        var finishBarrier: CheckedContinuation<Void, Never>?
        var delayStart = false
        var delayFinish = false
        var trailingText: String?

        func startListening() async throws {
            starts += 1
            if delayStart { await withCheckedContinuation { startBarrier = $0 } }
            // Intentionally ignore cancellation to exercise stale asynchronous startup.
            isListening = true
            delegate?.realtimeSTT(self, didChangeListeningState: true)
        }
        func stopListening() { stops += 1; isListening = false }
        func finishListening() async {
            finishes += 1
            if delayFinish { await withCheckedContinuation { finishBarrier = $0 } }
            if let trailingText { delegate?.realtimeSTT(self, didReceiveFinalResult: trailingText) }
            isListening = false
            delegate?.realtimeSTT(self, didChangeListeningState: false)
        }
        func availableModels() -> [RealtimeSTTModelInfo] { [] }
        func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {}
    }

    func testFinishCommitsTrailingResultOnceAndClearsTranscript() async {
        let session = VoiceInputSession(), stt = MockSTT()
        var commits: [String] = []
        await session.start(using: stt, authorize: { true }, canCommit: { true }, commit: { commits.append($0) }).value
        session.realtimeSTT(stt, didReceivePartialResult: "old partial")
        stt.trailingText = "  final transcript 😀  "
        let finish = session.finish()
        XCTAssertNil(session.finish())
        await finish?.value
        XCTAssertEqual(commits, ["final transcript 😀"])
        XCTAssertEqual(stt.finishes, 1)
        XCTAssertEqual(session.phase, .idle)
        XCTAssertEqual(session.text, "")
        XCTAssertNil(stt.delegate)
    }

    func testDestinationChangeDuringFinalizationDiscardsResult() async {
        let session = VoiceInputSession(), stt = MockSTT()
        stt.delayFinish = true
        var destinationValid = true, commits = 0
        await session.start(using: stt, authorize: { true }, canCommit: { destinationValid }, commit: { _ in commits += 1 }).value
        session.realtimeSTT(stt, didReceiveFinalResult: "private text")
        let finish = session.finish()
        while stt.finishBarrier == nil { await Task.yield() }
        destinationValid = false
        stt.finishBarrier?.resume()
        await finish?.value
        XCTAssertEqual(commits, 0)
        XCTAssertEqual(session.text, "")
    }

    func testCancellationWhilePermissionPromptIsPendingNeverStartsMicrophone() async {
        let session = VoiceInputSession(), stt = MockSTT()
        var permission: CheckedContinuation<Bool, Never>?
        let task = session.start(using: stt, authorize: {
            await withCheckedContinuation { permission = $0 }
        }, canCommit: { true }, commit: { _ in XCTFail("Cancelled session committed") })
        while permission == nil { await Task.yield() }
        session.cancel()
        permission?.resume(returning: true)
        await task.value
        XCTAssertEqual(stt.starts, 0)
        XCTAssertFalse(stt.isListening)
        XCTAssertEqual(session.phase, .idle)
    }

    func testNonCooperativeStartupIsStoppedAfterCancellation() async {
        let session = VoiceInputSession(), stt = MockSTT()
        stt.delayStart = true
        let task = session.start(using: stt, authorize: { true }, canCommit: { true }, commit: { _ in XCTFail("Stale session committed") })
        while stt.startBarrier == nil { await Task.yield() }
        session.cancel()
        stt.startBarrier?.resume()
        await task.value
        XCTAssertFalse(stt.isListening)
        XCTAssertEqual(session.phase, .idle)
        XCTAssertNil(stt.delegate)
    }

    func testCancelledFinalizationCannotCommitIntoNewSession() async {
        let session = VoiceInputSession(), old = MockSTT(), next = MockSTT()
        old.delayFinish = true
        var commits: [String] = []
        await session.start(using: old, authorize: { true }, canCommit: { true }, commit: { commits.append($0) }).value
        session.realtimeSTT(old, didReceivePartialResult: "old secret")
        let finish = session.finish()
        while old.finishBarrier == nil { await Task.yield() }
        await session.start(using: next, authorize: { true }, canCommit: { true }, commit: { commits.append($0) }).value
        session.realtimeSTT(old, didReceiveFinalResult: "late secret")
        old.finishBarrier?.resume()
        await finish?.value
        XCTAssertEqual(session.phase, .listening)
        XCTAssertTrue(next.isListening)
        XCTAssertEqual(session.text, "")
        session.realtimeSTT(next, didReceiveFinalResult: "new result")
        await session.finish()?.value
        XCTAssertEqual(commits, ["new result"])
    }

    func testPermissionDeniedAndInvalidDestinationNeverStartRecognition() async {
        for permitted in [false, true] {
            let session = VoiceInputSession(), stt = MockSTT()
            await session.start(using: stt, authorize: { permitted }, canCommit: { !permitted }, commit: { _ in XCTFail("Invalid destination committed") }).value
            XCTAssertEqual(stt.starts, 0)
            XCTAssertEqual(session.phase, .idle)
        }
    }

    func testErrorAndOversizedTranscriptCancelWithoutCommit() async {
        for oversized in [false, true] {
            let session = VoiceInputSession(), stt = MockSTT()
            await session.start(using: stt, authorize: { true }, canCommit: { true }, commit: { _ in XCTFail("Failed session committed") }).value
            if oversized {
                session.realtimeSTT(stt, didReceivePartialResult: String(repeating: "x", count: 100_001))
            } else {
                session.realtimeSTT(stt, didFailWithError: RealtimeSTTError.audioError("test"))
            }
            XCTAssertEqual(session.phase, .idle)
            XCTAssertFalse(stt.isListening)
            XCTAssertEqual(session.text, "")
            XCTAssertNil(session.finish())
        }
    }

    func testEmptyResultDoesNotInsertText() async {
        let session = VoiceInputSession(), stt = MockSTT()
        await session.start(using: stt, authorize: { true }, canCommit: { true }, commit: { _ in XCTFail("Empty result committed") }).value
        session.realtimeSTT(stt, didReceiveFinalResult: " \n ")
        await session.finish()?.value
        XCTAssertEqual(session.phase, .idle)
    }
}
