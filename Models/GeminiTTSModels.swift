/// Available Gemini speech models and default selection.
enum GeminiTTSModels {
    static let defaultID = "gemini-3.8-flash-tts"
    static let available: [TTSModelInfo] = [
        TTSModelInfo(id: defaultID, name: "Gemini 3.8 Flash TTS", description: "Expressive, multilingual", isDefault: true),
        TTSModelInfo(id: "gemini-3.8-flash-lite-tts", name: "Gemini 3.8 Flash-Lite TTS", description: "Lightweight, multilingual")
    ]

    static func resolvedID(_ savedID: String) -> String {
        ModelSelection.resolve(savedID, availableIDs: available.map(\.id), defaultID: defaultID)
    }
}
