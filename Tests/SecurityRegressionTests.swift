import XCTest
@testable import SpeechDock

final class SecurityRegressionTests: XCTestCase {
    @MainActor
    func testRecognitionRequestsRequireLocalProcessing() {
        let request = MacOSRealtimeSTT.makeRecognitionRequest()
        XCTAssertTrue(request.requiresOnDeviceRecognition)
        XCTAssertTrue(request.shouldReportPartialResults)
    }

    func testNetworkErrorLogsExcludeCredentialBearingURLs() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost,
                            userInfo: [NSURLErrorFailingURLStringErrorKey: "https://example.invalid/?key=FAKE_SECRET"])
        let summary = networkErrorSummary(error)
        XCTAssertTrue(summary.contains(NSURLErrorDomain))
        XCTAssertTrue(summary.contains(String(NSURLErrorCannotConnectToHost)))
        XCTAssertFalse(summary.contains("FAKE_SECRET"))
        XCTAssertFalse(summary.contains("example.invalid"))
    }

    @MainActor
    func testAudioImportRejectsSymlinksAndNonRegularFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let audio = directory.appendingPathComponent("audio.mp3")
        try Data("small audio".utf8).write(to: audio)
        let link = directory.appendingPathComponent("link.mp3")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: audio)
        XCTAssertThrowsError(try FileTranscriptionService.shared.validateFile(link, for: .openAI))
        XCTAssertThrowsError(try FileTranscriptionService.shared.readAudioData(link, for: .openAI))
        let subdirectory = directory.appendingPathComponent("directory.mp3")
        try FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: false)
        XCTAssertThrowsError(try FileTranscriptionService.shared.readAudioData(subdirectory, for: .openAI))
        XCTAssertEqual(try FileTranscriptionService.shared.readAudioData(audio, for: .openAI), Data("small audio".utf8))
    }

    @MainActor
    func testAudioImportRejectsOversizedSparseFile() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).mp3")
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let handle = try FileHandle(forWritingTo: file)
        try handle.truncate(atOffset: UInt64(RealtimeSTTProvider.openAI.maxFileSizeMB * 1024 * 1024 + 1))
        try handle.close()
        XCTAssertThrowsError(try FileTranscriptionService.shared.readAudioData(file, for: .openAI)) { error in
            guard case FileTranscriptionError.fileTooLarge = error else { return XCTFail("Expected size limit error") }
        }
    }
}
