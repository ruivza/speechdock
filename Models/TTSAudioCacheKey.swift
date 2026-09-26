struct TTSAudioCacheKey: Equatable {
    let text: String
    let provider: TTSProvider
    let model: String
    let voice: String
    let speed: Double
    let language: String
    let rules: [TextReplacementRule]
    let builtInSettings: [BuiltInPattern: BuiltInPatternSetting]
}
