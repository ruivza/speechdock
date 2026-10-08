import XCTest
@testable import SpeechDock

final class InputMethodInstallationTests: XCTestCase {
    private func component(in root: URL) throws -> URL {
        let app = root.appendingPathComponent("SpeechDockVoiceInput.app")
        let contents = app.appendingPathComponent("Contents")
        let executables = contents.appendingPathComponent("MacOS")
        try FileManager.default.createDirectory(at: executables, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "com.speechdock.inputmethod.voice.dev",
                                   "CFBundleExecutable": "SpeechDockVoiceInput", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        let executable = executables.appendingPathComponent("SpeechDockVoiceInput")
        try Data("test fixture".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        return app
    }

    func testInstallPreservesFilesAndRefusesOverwrite() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try component(in: root)
        let directory = root.appendingPathComponent("Input Methods")
        let installed = try InputMethodInstallationService.install(component: app, in: directory)
        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: installed.appendingPathComponent("Contents/MacOS/SpeechDockVoiceInput").path))
        XCTAssertThrowsError(try InputMethodInstallationService.install(component: app, in: directory))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["SpeechDockVoiceInput.app"])
    }

    func testInstallRejectsDirectorySymlinkAndInvalidComponent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try component(in: root)
        let directory = root.appendingPathComponent("actual")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let link = root.appendingPathComponent("Input Methods")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory)
        XCTAssertThrowsError(try InputMethodInstallationService.install(component: app, in: link))
        XCTAssertThrowsError(try InputMethodInstallationService.install(component: root, in: directory))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }

    func testInstallDoesNotFollowDanglingDestinationLink() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try component(in: root)
        let directory = root.appendingPathComponent("Input Methods")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let destination = directory.appendingPathComponent("SpeechDockVoiceInput.app")
        let missing = root.appendingPathComponent("missing")
        try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: missing)
        XCTAssertThrowsError(try InputMethodInstallationService.install(component: app, in: directory))
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), ["SpeechDockVoiceInput.app"])
    }

    func testInstallRejectsDirectoryWritableByOtherUsers() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try component(in: root)
        let directory = root.appendingPathComponent("Input Methods")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o702], ofItemAtPath: directory.path)
        XCTAssertThrowsError(try InputMethodInstallationService.install(component: app, in: directory))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }
}
