import XCTest
@testable import SpeechDock

final class GeminiTTSTests: XCTestCase {
    func testCurrentModelsAndUnknownSelection() {
        let ids = ["gemini-3.8-flash-tts", "gemini-3.8-flash-lite-tts"]
        XCTAssertEqual(GeminiTTSModels.available.map(\.id), ids)
        XCTAssertEqual(GeminiTTSModels.available.filter(\.isDefault).map(\.id), [ids[0]])
        for id in ids {
            XCTAssertEqual(GeminiTTSModels.resolvedID(id), id)
        }
        for id in ["", "unknown", "removed-model"] {
            XCTAssertEqual(GeminiTTSModels.resolvedID(id), ids[0])
        }
    }

    private func part(_ data: Data, _ mime: String = "audio/wav") -> [String: Any] {
        ["inlineData": ["mimeType": mime, "data": data.base64EncodedString()]]
    }

    func testWAVPartsJoinWithoutEmbeddedHeadersAndPreserveRate() throws {
        let pcm = Data([1, 0, 2, 0])
        let wav = AudioConverter.createWAVFromPCM(pcm, sampleRate: 48000)
        let result = try GeminiTTSAudio.makeWAV(from: [part(wav), part(wav)])
        XCTAssertEqual(result, AudioConverter.createWAVFromPCM(pcm + pcm, sampleRate: 48000))
    }

    func testRawPCMAndMixedContainers() throws {
        let pcm = Data([1, 0, 2, 0])
        let wav = AudioConverter.createWAVFromPCM(pcm)
        XCTAssertEqual(try GeminiTTSAudio.makeWAV(from: [part(pcm, "audio/l16; rate=24000"), part(wav)]), AudioConverter.createWAVFromPCM(pcm + pcm))
        XCTAssertEqual(try GeminiTTSAudio.makeWAV(from: [part(pcm)]), wav)
    }

    func testRejectDifferentRatesChannelsAndBitDepths() {
        let wav = AudioConverter.createWAVFromPCM(Data([1, 0, 2, 0]))
        let differentRate = AudioConverter.createWAVFromPCM(Data([1, 0, 2, 0]), sampleRate: 48000)
        XCTAssertThrowsError(try GeminiTTSAudio.makeWAV(from: [part(wav), part(differentRate)]))
        var stereo = wav
        stereo[22] = 2; stereo[28] = 0; stereo[29] = 119; stereo[30] = 1; stereo[32] = 4
        XCTAssertThrowsError(try GeminiTTSAudio.makeWAV(from: [part(wav), part(stereo)]))
        var bits32 = stereo
        bits32[22] = 1; bits32[34] = 32
        XCTAssertThrowsError(try GeminiTTSAudio.makeWAV(from: [part(wav), part(bits32)]))
    }

    func testRejectMalformedAudio() {
        let wav = AudioConverter.createWAVFromPCM(Data([1, 0]))
        XCTAssertThrowsError(try GeminiTTSAudio.makeWAV(from: [part(Data(wav.dropLast()))]))
        XCTAssertThrowsError(try GeminiTTSAudio.makeWAV(from: [part(Data([1]))]))
        XCTAssertThrowsError(try GeminiTTSAudio.makeWAV(from: []))
        XCTAssertThrowsError(try GeminiTTSAudio.makeWAV(from: [["inlineData": ["data": "!"]]]))
        XCTAssertThrowsError(try GeminiTTSAudio.makeWAV(from: [part(Data([0, 0]), "audio/mp3")]))
    }

    func testSkipPaddedMetadataChunk() throws {
        let pcm = Data([1, 0, 2, 0])
        let wav = AudioConverter.createWAVFromPCM(pcm)
        var withMetadata = wav
        withMetadata.insert(contentsOf: Array("JUNK".utf8) + [1, 0, 0, 0, 42, 0], at: 12)
        withMetadata[4] += 10
        XCTAssertEqual(try GeminiTTSAudio.makeWAV(from: [part(withMetadata)]), wav)
    }
}
