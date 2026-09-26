import XCTest
@testable import SpeechDock

final class TranslationSelectionTests: XCTestCase {
    func testMissingCloudKeyUsesMacOSAndSystemModel() {
        for preferred in [TranslationProvider.gemini, .openAI, .grok] {
            let selection = TranslationSelection.resolve(preferred: preferred, target: .japanese,
                savedModel: preferred.defaultModelId, macOSAvailable: true, hasAPIKey: { _ in false })
            XCTAssertEqual(selection.provider, .macOS)
            XCTAssertEqual(selection.modelID, "system")
            XCTAssertNotNil(selection.fallbackReason)
        }
    }

    func testAvailablePreferenceAndModelArePreserved() {
        let model = TranslationProvider.gemini.availableModels.last!.id
        let selection = TranslationSelection.resolve(preferred: .gemini, target: .japanese,
            savedModel: model, macOSAvailable: true, hasAPIKey: { $0 == .gemini })
        XCTAssertEqual(selection.provider, .gemini)
        XCTAssertEqual(selection.modelID, model)
        XCTAssertNil(selection.fallbackReason)
    }

    func testFallbackCloudProviderUsesItsOwnModel() {
        let selection = TranslationSelection.resolve(preferred: .gemini, target: .japanese,
            savedModel: TranslationProvider.gemini.defaultModelId, macOSAvailable: false, hasAPIKey: { $0 == .openAI })
        XCTAssertEqual(selection.provider, .openAI)
        XCTAssertEqual(selection.modelID, TranslationProvider.openAI.defaultModelId)
    }

    func testUnavailableMacOSDoesNotOverrideAvailableCloudProvider() {
        let selection = TranslationSelection.resolve(preferred: .macOS, target: .japanese,
            savedModel: "system", macOSAvailable: false, hasAPIKey: { $0 == .grok })
        XCTAssertEqual(selection.provider, .grok)
        XCTAssertNotNil(selection.fallbackReason)
    }

    @MainActor
    func testSubtitleUsesSameEffectiveProviderAsPanel() async {
        let app = AppState(startServices: false)
        app.translationProvider = .gemini
        app.translationTargetLanguage = .japanese
        app.subtitleTranslationEnabled = true
        var received: TranslationProvider?
        var model: String?
        let service = SubtitleTranslationService(makeTranslator: { received = $0; model = $1; return nil })
        await service.processTextUpdate("", isFinal: true, appState: app)
        XCTAssertEqual(received, app.effectiveTranslationProvider)
        XCTAssertEqual(received, .macOS)
        XCTAssertEqual(model, "system")
        XCTAssertEqual(app.translationProvider, .gemini)
    }
}
