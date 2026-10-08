import XCTest
@testable import SpeechDock

@MainActor
final class TranscriptionHistoryTests: XCTestCase {
    private func fixture() throws -> (TranscriptionHistoryService, UserDefaults, URL) {
        let name = "speechdock-history-test-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: directory)
        }
        return (TranscriptionHistoryService(defaults: defaults, directoryURL: directory), defaults, directory)
    }

    func testDisabledHistoryDoesNotCreateFiles() throws {
        let (service, _, directory) = try fixture()
        service.isEnabled = false
        service.addEntry(text: "private test transcript", provider: "test")
        XCTAssertTrue(service.allEntries.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testHistoryLimitPermissionsAndReload() throws {
        let (service, defaults, directory) = try fixture()
        for i in 0..<55 { service.addEntry(text: "entry \(i)", provider: "test") }
        XCTAssertEqual(service.allEntries.count, 50)
        XCTAssertEqual(service.allEntries.first?.text, "entry 54")
        let file = directory.appendingPathComponent("transcription_history.json")
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber)?.intValue, 0o700)
        XCTAssertEqual((try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        let reloaded = TranscriptionHistoryService(defaults: defaults, directoryURL: directory)
        XCTAssertEqual(reloaded.allEntries.count, 50)
    }

    func testDisablingPreservesExistingFileUntilExplicitClear() throws {
        let (service, defaults, directory) = try fixture()
        service.addEntry(text: "saved entry", provider: "test")
        let file = directory.appendingPathComponent("transcription_history.json")
        let previous = try Data(contentsOf: file)
        service.isEnabled = false
        service.addEntry(text: "unsaved entry", provider: "test")
        XCTAssertEqual(try Data(contentsOf: file), previous)
        XCTAssertTrue(TranscriptionHistoryService(defaults: defaults, directoryURL: directory).allEntries.isEmpty)
        service.isEnabled = true
        XCTAssertEqual(service.allEntries.map(\.text), ["saved entry"])
        service.isEnabled = false
        service.clearHistory()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        service.isEnabled = true
        XCTAssertTrue(service.allEntries.isEmpty)
    }
}
