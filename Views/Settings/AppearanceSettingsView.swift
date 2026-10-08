import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(AppState.self) var appState
    @AppStorage("interfaceLanguage") private var interfaceLanguage = ""
    @State private var showLanguageRestartNotice = false
    @State private var cacheCleared = false

    var body: some View {
        @Bindable var appState = appState

        Form {
            Section("Language") {
                Picker("Interface Language", selection: $interfaceLanguage) {
                    ForEach(InterfaceLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .onChange(of: interfaceLanguage) { _, value in
                    (InterfaceLanguage(rawValue: value) ?? .system).apply()
                    showLanguageRestartNotice = true
                }
                Text("Quit and reopen SpeechDock to apply the interface language. Speech and translation languages are configured separately.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Text Font Size")
                        Spacer()
                        Text("\(Int(appState.panelTextFontSize)) pt")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    HStack(spacing: 8) {
                        Slider(
                            value: $appState.panelTextFontSize,
                            in: 10...24,
                            step: 1
                        ) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("A")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } maximumValueLabel: {
                            Text("A")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }

                        Button("Reset") {
                            appState.panelTextFontSize = 13.0
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }

                    Text("Font size for text in STT and TTS panels.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Picker("Panel Style", selection: $appState.panelStyle) {
                    ForEach(PanelStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .onChange(of: appState.panelStyle) { _, _ in
                    if appState.floatingWindowManager.isVisible {
                        appState.floatingWindowManager.closePanel()
                    }
                }

                Text("Floating: Always-on-top borderless panels. Standard Window: Regular windows with title bar. Only one panel (STT or TTS) can be open at a time.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } header: {
                Text("Panel Appearance")
            }

            Section {
                LaunchAtLoginToggle()
            } header: {
                Text("Startup")
            }
            Section("Cache") {
                Button(cacheCleared ? NSLocalizedString("Cache Cleared", comment: "Cache status") : NSLocalizedString("Clear Cache", comment: "Cache action")) {
                    appState.stopTTS()
                    for provider in TTSProvider.allCases { TTSVoiceCache.shared.clearCache(for: provider) }
                    URLCache.shared.removeAllCachedResponses()
                    cacheCleared = true
                }
                .disabled(appState.ttsState == .loading || appState.ttsState == .speaking || appState.ttsState == .paused)
                Text("Clears voice lists and network cache. Temporary audio is cleaned automatically. History, API keys, saved audio and Apple language models are kept.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.visible)
        .alert("Restart Required", isPresented: $showLanguageRestartNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Quit and reopen SpeechDock to apply the interface language.")
        }
    }
}

// MARK: - Component Views

/// Toggle for launch at login setting
struct LaunchAtLoginToggle: View {
    @State private var isEnabled: Bool = LaunchAtLoginService.shared.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Launch at Login", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, newValue in
                    LaunchAtLoginService.shared.isEnabled = newValue
                }
                .disabled(!LaunchAtLoginService.shared.isAvailable)

            if LaunchAtLoginService.shared.isAvailable {
                Text("SpeechDock will start automatically when you log in")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Launch at login requires macOS 13 or later")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
        .onAppear {
            isEnabled = LaunchAtLoginService.shared.isEnabled
        }
    }
}
