import Foundation

/// Keychain access used by APIKeyManager. Replaced in tests.
protocol APIKeyStore {
    func retrieve(key: String) -> String?
    func save(key: String, value: String) throws
    func delete(key: String) throws
}

extension KeychainService: APIKeyStore {}

final class APIKeyManager {
    static let shared = APIKeyManager()

    /// Canonical key names and the older names still accepted, in reading order.
    static let keyNameAliases: [String: [String]] = [
        "XAI_API_KEY": ["XAI_API_KEY", "GROK_API_KEY"]
    ]

    /// The canonical name for `name` (an older name maps to the current one).
    static func canonicalName(_ name: String) -> String {
        keyNameAliases.first { $0.value.contains(name) }?.key ?? name
    }

    /// Names to look up for `name`, the canonical one first.
    static func candidateNames(_ name: String) -> [String] {
        let canonical = canonicalName(name)
        return keyNameAliases[canonical] ?? [canonical]
    }

    private let keychain: APIKeyStore
    private let environment: () -> [String: String]
    private let testModeNoAPIKeys: Bool

    init(keychain: APIKeyStore = KeychainService(),
         environment: @escaping () -> [String: String] = { ProcessInfo.processInfo.environment },
         testModeNoAPIKeys: Bool = ProcessInfo.processInfo.environment["SPEECHDOCK_TEST_NO_API_KEYS"] == "1") {
        self.keychain = keychain
        self.environment = environment
        self.testModeNoAPIKeys = testModeNoAPIKeys
    }

    // MARK: - Lookup

    /// Where a configured key was found.
    struct KeyOrigin: Equatable {
        let source: APIKeySource
        /// The name it was found under (may be an older name).
        let name: String
        /// The stored text, including invalid values that Settings can replace.
        let storedValue: String

        var isLegacyName: Bool { APIKeyManager.canonicalName(name) != name }
    }

    /// Environment variables first, then the keychain; within each, the
    /// canonical name before older ones.
    func keyOrigin(for name: String) -> KeyOrigin? {
        guard !testModeNoAPIKeys else { return nil }
        let names = Self.candidateNames(name)
        let env = environment()
        for candidate in names {
            if let value = env[candidate], !value.isEmpty {
                return KeyOrigin(source: .environment, name: candidate, storedValue: value)
            }
        }
        for candidate in names {
            if let value = keychain.retrieve(key: candidate), !value.isEmpty {
                return KeyOrigin(source: .keychain, name: candidate, storedValue: value)
            }
        }
        return nil
    }

    func keyOrigin(for provider: STTProvider) -> KeyOrigin? {
        keyOrigin(for: provider.envKeyName)
    }

    // MARK: - Reads

    /// Only literal API keys can be sent to providers. Stored URLs remain
    /// visible in Settings but are never returned as credentials.
    func getAPIKey(for name: String) -> String? {
        guard let origin = keyOrigin(for: name), Self.isUsableKey(origin.storedValue) else { return nil }
        return origin.storedValue
    }

    func getAPIKey(for provider: STTProvider) -> String? {
        getAPIKey(for: provider.envKeyName)
    }

    /// For enabling choices in the UI: a usable key is set.
    func hasAPIKey(for name: String) -> Bool {
        getAPIKey(for: name) != nil
    }

    func hasAPIKey(for provider: STTProvider) -> Bool {
        hasAPIKey(for: provider.envKeyName)
    }

    func apiKeySource(for provider: STTProvider) -> APIKeySource {
        keyOrigin(for: provider)?.source ?? .none
    }

    /// The keychain's stored text for the canonical name or an older one
    /// for the Settings field.
    func storedKeychainValue(for provider: STTProvider) -> String? {
        guard !testModeNoAPIKeys else { return nil }
        for candidate in Self.candidateNames(provider.envKeyName) {
            if let value = keychain.retrieve(key: candidate), !value.isEmpty { return value }
        }
        return nil
    }

    /// Async entry point retained for provider clients.
    func apiKey(for name: String) async -> String? {
        getAPIKey(for: name)
    }

    func apiKey(for provider: STTProvider) async -> String? {
        await apiKey(for: provider.envKeyName)
    }

    /// Reports unavailable credentials without including their stored text.
    func unavailableReason(for name: String) -> String {
        let providerName = Self.providerDisplayName(for: name)
        if let origin = keyOrigin(for: name), !Self.isUsableKey(origin.storedValue) {
            return String(format: NSLocalizedString("%@ API key: %@", comment: "API key unavailable: provider, reason"),
                          providerName, NSLocalizedString("Enter the API key itself, not a URL.", comment: "Invalid API key format"))
        }
        return String(format: NSLocalizedString("%@ API key not found", comment: "API key unavailable: provider"),
                      providerName)
    }

    func unavailableReason(for provider: STTProvider) -> String {
        unavailableReason(for: provider.envKeyName)
    }

    // MARK: - Writing

    /// Saves under the canonical name. Once that succeeds, items under older
    /// names are removed, so a replaced key does not linger behind the new one.
    /// Nothing is moved on its own: this runs only when the user saves.
    func setAPIKey(_ key: String, for provider: STTProvider) throws {
        guard Self.isUsableKey(key) else { throw KeychainError.invalidData }
        let canonical = Self.canonicalName(provider.envKeyName)
        try keychain.save(key: canonical, value: key)
        for legacy in Self.candidateNames(canonical) where legacy != canonical {
            try? keychain.delete(key: legacy)
        }
    }

    /// Removes the key under every accepted name.
    func deleteAPIKey(for provider: STTProvider) throws {
        for candidate in Self.candidateNames(provider.envKeyName) {
            try keychain.delete(key: candidate)
        }
    }

    // MARK: - Helpers

    static func providerDisplayName(for name: String) -> String {
        let canonical = canonicalName(name)
        return STTProvider.allCases.first { canonicalName($0.envKeyName) == canonical }?.rawValue ?? canonical
    }

    static func isUsableKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !trimmed.contains("://")
    }
}

enum APIKeySource {
    case environment  // From shell environment (development/terminal launch)
    case keychain     // From macOS Keychain (recommended)
    case none
}
