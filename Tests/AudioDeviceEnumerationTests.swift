import CoreAudio
import XCTest
@testable import SpeechDock

final class AudioDeviceEnumerationTests: XCTestCase {
    func testZeroStreamHeaderDoesNotReadTheAbsentFirstBuffer() {
        // Core Audio returns an eight-byte header for devices with no streams
        // in the requested direction; AudioBufferList itself is larger.
        let data = UnsafeMutableRawPointer.allocate(byteCount: 8, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { data.deallocate() }
        data.storeBytes(of: UInt32(0), as: UInt32.self)
        XCTAssertFalse(audioStreamConfigurationHasBuffers(data, byteCount: 8))
    }

    func testTruncatedHeaderIsRejectedWithoutReadingPastItsAllocation() {
        for byteCount in 0..<MemoryLayout<UInt32>.size {
            let data = UnsafeMutableRawPointer.allocate(byteCount: max(1, byteCount), alignment: MemoryLayout<AudioBufferList>.alignment)
            XCTAssertFalse(audioStreamConfigurationHasBuffers(data, byteCount: UInt32(byteCount)))
            data.deallocate()
        }
    }

    func testSingleAndMultipleStreamHeadersAreRecognized() {
        for count: UInt32 in [1, 3] {
            let byteCount = MemoryLayout<AudioBufferList>.size + Int(count - 1) * MemoryLayout<AudioBuffer>.stride
            let data = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: MemoryLayout<AudioBufferList>.alignment)
            data.storeBytes(of: count, as: UInt32.self)
            XCTAssertTrue(audioStreamConfigurationHasBuffers(data, byteCount: UInt32(byteCount)))
            data.deallocate()
        }
    }

    func testLiveDeviceEnumerationKeepsTheSystemDefault() {
        AudioInputManager.shared.clearCache()
        AudioOutputManager.shared.clearCache()
        XCTAssertEqual(AudioInputManager.shared.availableInputDevices().first, .systemDefault)
        XCTAssertEqual(AudioOutputManager.shared.availableOutputDevices().first, .systemDefault)
    }
}
