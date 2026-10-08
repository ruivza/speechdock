import Foundation

enum RealtimeSTTFactory {
    @MainActor
    static func makeService(for provider: RealtimeSTTProvider) -> RealtimeSTTService {
        switch provider {
        case .macOS: return OnDeviceSTTFactory.makeService()
        case .openAI: return OpenAIRealtimeSTT()
        case .gemini: return GeminiRealtimeSTT()
        case .elevenLabs: return ElevenLabsRealtimeSTT()
        case .grok: return GrokRealtimeSTT()
        }
    }
}
