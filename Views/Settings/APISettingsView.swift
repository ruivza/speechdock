import SwiftUI

struct APISettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("SpeechDock works without API keys using macOS built-in STT/TTS. Cloud providers below are optional and offer additional voices, models, and languages.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                Text("Each field takes the key itself or a 1Password reference (op://vault/item/field). A reference is read with the 1Password CLI (op) when Settings opens or a key is first needed; only the reference is stored in the keychain.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            } header: {
                Text("About API Keys")
            }
            ForEach(STTProvider.allCases) { provider in
                APIKeySection(provider: provider)
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.visible)
        .padding()
        .task {
            // Opening Settings reads every 1Password reference at once (one approval).
            await APIKeyManager.shared.prepareReferences()
        }
    }
}

struct APIKeySection: View {
    let provider: STTProvider

    @State private var apiKey: String = ""
    @State private var showKey: Bool = false
    @State private var isSaving: Bool = false
    @State private var isValidating: Bool = false
    @State private var saveMessage: String?
    @State private var saveMessageColor: Color = .green

    private let apiKeyManager = APIKeyManager.shared

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if showKey {
                        TextField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.leading)
                    } else {
                        SecureField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.leading)
                    }

                    Button(action: { showKey.toggle() }) {
                        Image(systemName: showKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }

                HStack {
                    keySourceBadge

                    Spacer()

                    if isValidating {
                        ProgressView()
                            .controlSize(.small)
                        Text("Validating...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let message = saveMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(saveMessageColor)
                    }

                    Button("Save to Keychain") {
                        Task {
                            await saveAPIKey()
                        }
                    }
                    .disabled(apiKey.isEmpty || isSaving || isValidating)

                    if case .failed = apiKeyManager.keyStatus(for: provider) {
                        Button("Reload from 1Password") {
                            Task { await apiKeyManager.reloadReference(for: provider) }
                        }
                    }

                    if apiKeyManager.apiKeySource(for: provider) == .keychain {
                        Button("Remove") {
                            removeAPIKey()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        } header: {
            Text(provider.rawValue)
        } footer: {
            Text(provider.footerDescription)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            loadAPIKey()
        }
    }

    @ViewBuilder
    private var keySourceBadge: some View {
        let origin = apiKeyManager.keyOrigin(for: provider)

        HStack(spacing: 8) {
            switch origin?.source ?? .none {
            case .environment:
                Label(environmentLabel(origin), systemImage: "terminal")
                    .font(.caption)
                    .foregroundColor(.blue)
            case .keychain:
                Label("From Keychain", systemImage: "key.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            case .none:
                Label("Not Set", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            if origin?.isReference == true {
                referenceStatus
            }
        }
    }

    /// The variable the key came from; an older name is marked as such.
    private func environmentLabel(_ origin: APIKeyManager.KeyOrigin?) -> String {
        guard let origin else { return NSLocalizedString("From Environment", comment: "API key source") }
        if origin.isLegacyName {
            return String(format: NSLocalizedString("From Environment (%@, older name)", comment: "API key source: variable name"), origin.name)
        }
        return String(format: NSLocalizedString("From Environment (%@)", comment: "API key source: variable name"), origin.name)
    }

    /// The reference's state, by reason only; the reference text is not shown here.
    @ViewBuilder
    private var referenceStatus: some View {
        switch apiKeyManager.keyStatus(for: provider) {
        case .ready:
            Label("1Password: read", systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundColor(.green)
        case .pending:
            Label("1Password: read when first used", systemImage: "clock")
                .font(.caption)
                .foregroundColor(.secondary)
        case .failed(let failure):
            Label(failure.localizedDescription, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.orange)
        case .notSet:
            EmptyView()
        }
    }

    private func loadAPIKey() {
        // The stored text: the key, or a 1Password reference (never its value).
        apiKey = apiKeyManager.storedKeychainValue(for: provider) ?? ""
    }

    private func saveAPIKey() async {
        isValidating = true
        saveMessage = nil

        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let result: ValidationResult
        if SecretReference.isReference(trimmed) {
            result = await validateReference(trimmed)
        } else {
            result = await APIKeyValidator.validate(key: trimmed, for: provider)
        }
        isValidating = false

        switch result {
        case .valid:
            isSaving = true
            do {
                try apiKeyManager.setAPIKey(trimmed, for: provider)
                saveMessageColor = .green
                saveMessage = "Valid ✓ Saved!"
            } catch {
                saveMessageColor = .red
                saveMessage = "Error: \(error.localizedDescription)"
            }
            isSaving = false

        case .invalid(let reason):
            saveMessageColor = .red
            saveMessage = reason

        case .networkError:
            isSaving = true
            do {
                try apiKeyManager.setAPIKey(trimmed, for: provider)
                saveMessageColor = .orange
                saveMessage = "Could not verify (saved anyway)"
            } catch {
                saveMessageColor = .red
                saveMessage = "Error: \(error.localizedDescription)"
            }
            isSaving = false
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            saveMessage = nil
        }
    }

    /// Reads the reference with `op read` and validates the value it gives.
    /// Only the reference is saved; the value stays in memory.
    private func validateReference(_ reference: String) async -> ValidationResult {
        guard SecretReference.isWellFormed(reference) else {
            return .invalid(NSLocalizedString("Use the form op://vault/item/field", comment: "1Password reference format"))
        }
        switch await apiKeyManager.readReference(reference) {
        case .success(let value):
            return await APIKeyValidator.validate(key: value, for: provider)
        case .failure(let failure):
            return .invalid(failure.localizedDescription)
        }
    }

    private func removeAPIKey() {
        do {
            try apiKeyManager.deleteAPIKey(for: provider)
            apiKey = ""
            saveMessage = "Removed"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                saveMessage = nil
            }
        } catch {
            saveMessage = "Error: \(error.localizedDescription)"
        }
    }
}
