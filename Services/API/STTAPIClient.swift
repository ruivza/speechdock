import Foundation

protocol STTAPIClient {
    func transcribe(
        audioData: Data,
        model: STTModel,
        language: String?,
        originalExtension: String?
    ) async throws -> TranscriptionResult
}
