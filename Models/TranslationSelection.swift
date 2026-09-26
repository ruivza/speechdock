import Foundation

/// One resolved selection for translation UI and execution.
struct TranslationSelection {
    let provider: TranslationProvider
    let modelID: String
    let fallbackReason: String?

    static func resolve(preferred: TranslationProvider?, target: LanguageCode, savedModel: String,
                        macOSAvailable: Bool, hasAPIKey: (TranslationProvider) -> Bool) -> Self {
        func available(_ provider: TranslationProvider) -> Bool {
            provider.supportsLanguage(target) && (provider == .macOS ? macOSAvailable : hasAPIKey(provider))
        }
        let provider = preferred.flatMap { available($0) ? $0 : nil }
            ?? [.macOS, .openAI, .gemini, .grok].first(where: available) ?? .macOS
        let reason: String?
        if let preferred, preferred != provider {
            if preferred.requiresAPIKey && !hasAPIKey(preferred) {
                reason = NSLocalizedString("API key not set", comment: "Translation fallback reason")
            } else if preferred == .macOS && !macOSAvailable {
                reason = NSLocalizedString("Requires macOS 26+", comment: "Translation fallback reason")
            } else {
                reason = NSLocalizedString("Language not supported", comment: "Translation fallback reason")
            }
        } else { reason = nil }
        return Self(provider: provider,
                    modelID: ModelSelection.resolve(savedModel, availableIDs: provider.availableModels.map(\.id), defaultID: provider.defaultModelId),
                    fallbackReason: reason)
    }
}
