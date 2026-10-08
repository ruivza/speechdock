import XCTest
@testable import SpeechDock

private final class MemoryAPIKeyStore: APIKeyStore {
    var items: [String: String] = [:]
    var reads = 0
    var rejectSave = false
    func retrieve(key: String) -> String? { reads += 1; return items[key] }
    func save(key: String, value: String) throws {
        if rejectSave { throw KeychainError.invalidData }
        items[key] = value
    }
    func delete(key: String) throws { items[key] = nil }
}

final class APIKeyManagerTests: XCTestCase {

    func testSTTProviderEnvironmentVariableNames() {
        // Verify environment variable names are correct
        XCTAssertEqual(STTProvider.openAI.envKeyName, "OPENAI_API_KEY")
        XCTAssertEqual(STTProvider.gemini.envKeyName, "GEMINI_API_KEY")
        XCTAssertEqual(STTProvider.elevenLabs.envKeyName, "ELEVENLABS_API_KEY")
    }

    func testSTTProviderKeychainKeys() {
        // Verify keychain keys (envKeyName) are unique for each provider
        let keys = STTProvider.allCases.map { $0.envKeyName }
        let uniqueKeys = Set(keys)

        XCTAssertEqual(keys.count, uniqueKeys.count, "All keychain keys should be unique")
    }

    func testHasAPIKeyReturnsFalseForMissingKey() {
        let keys = manager()
        XCTAssertFalse(keys.hasAPIKey(for: .openAI))
        XCTAssertEqual(keys.apiKeySource(for: .openAI), .none)
    }

    private func manager(env: [String: String] = [:], store: MemoryAPIKeyStore = MemoryAPIKeyStore()) -> APIKeyManager {
        APIKeyManager(keychain: store, environment: { env }, testModeNoAPIKeys: false)
    }

    func testLiteralKeysWorkSynchronouslyAndAsynchronously() async {
        for provider in STTProvider.allCases {
            let keys = manager(env: [provider.envKeyName: "fake-literal-key"])
            XCTAssertEqual(keys.getAPIKey(for: provider), "fake-literal-key")
            let key = await keys.apiKey(for: provider)
            XCTAssertEqual(key, "fake-literal-key")
            XCTAssertTrue(keys.hasAPIKey(for: provider))
            XCTAssertEqual(keys.apiKeySource(for: provider), .environment)
        }
    }

    func testEnvironmentAndGrokAliasPrecedence() {
        let store = MemoryAPIKeyStore()
        store.items = ["XAI_API_KEY": "kc-xai", "GROK_API_KEY": "kc-grok"]
        XCTAssertEqual(manager(env: ["XAI_API_KEY": "env-xai", "GROK_API_KEY": "env-grok"], store: store).getAPIKey(for: .grok), "env-xai")
        XCTAssertEqual(manager(env: ["GROK_API_KEY": "env-grok"], store: store).getAPIKey(for: .grok), "env-grok")
        XCTAssertEqual(manager(store: store).getAPIKey(for: .grok), "kc-xai")
        store.items["XAI_API_KEY"] = nil
        let keys = manager(store: store)
        XCTAssertEqual(keys.getAPIKey(for: "GROK_API_KEY"), "kc-grok")
        XCTAssertEqual(keys.keyOrigin(for: .grok)?.isLegacyName, true)
        XCTAssertEqual(store.items["GROK_API_KEY"], "kc-grok")
    }

    func testSavingAndRemovingGrokKeysMaintainsAliasMigration() throws {
        let store = MemoryAPIKeyStore()
        store.items["GROK_API_KEY"] = "old"
        let keys = manager(store: store)
        try keys.setAPIKey("new", for: .grok)
        XCTAssertEqual(store.items, ["XAI_API_KEY": "new"])
        store.items["GROK_API_KEY"] = "old"
        try keys.deleteAPIKey(for: .grok)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testFailedSavePreservesExistingKey() {
        let store = MemoryAPIKeyStore()
        store.items["GROK_API_KEY"] = "old"
        store.rejectSave = true
        XCTAssertThrowsError(try manager(store: store).setAPIKey("new", for: .grok))
        XCTAssertEqual(store.items, ["GROK_API_KEY": "old"])
    }

    func testStoredURLsNeverBecomeCredentials() async {
        for value in ["op://Test/FAKE_KEY/credential", " https://example.invalid/private \n"] {
            let store = MemoryAPIKeyStore()
            store.items["OPENAI_API_KEY"] = value
            for keys in [manager(store: store), manager(env: ["OPENAI_API_KEY": value])] {
                XCTAssertNil(keys.getAPIKey(for: .openAI))
                let key = await keys.apiKey(for: .openAI)
                XCTAssertNil(key)
                XCTAssertFalse(keys.hasAPIKey(for: .openAI))
                XCTAssertFalse(keys.unavailableReason(for: .openAI).contains(value.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
            let keys = manager(store: store)
            XCTAssertEqual(keys.storedKeychainValue(for: .openAI), value)
            XCTAssertThrowsError(try keys.setAPIKey(value, for: .openAI))
            XCTAssertEqual(store.items["OPENAI_API_KEY"], value)
        }
    }

    func testValidatorRejectsURLsBeforeNetworking() async {
        for provider in STTProvider.allCases {
            let result = await APIKeyValidator.validate(key: "op://Test/FAKE_KEY/credential", for: provider)
            guard case .invalid = result else { return XCTFail("URL values must be rejected locally") }
        }
    }

    func testNoAPIKeyModeDoesNotReadStore() async {
        let store = MemoryAPIKeyStore()
        store.items["OPENAI_API_KEY"] = "fake-key"
        let keys = APIKeyManager(keychain: store, environment: { ["OPENAI_API_KEY": "env-key"] }, testModeNoAPIKeys: true)
        XCTAssertNil(keys.getAPIKey(for: .openAI))
        let key = await keys.apiKey(for: .openAI)
        XCTAssertNil(key)
        XCTAssertNil(keys.storedKeychainValue(for: .openAI))
        XCTAssertEqual(store.reads, 0)
    }
}
