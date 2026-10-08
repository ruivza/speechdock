import SwiftUI

// Modified by ruivza: remove update/support actions and distinguish fork attribution.
struct AboutSettingsView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // App Icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)

            // App Name & Version
            Text("SpeechDock")
                .font(.system(size: 20, weight: .bold))

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("Maintainer: ruivza")
                .font(.caption)
                .foregroundColor(.secondary)

            // Links
            HStack(spacing: 16) {
                Button(action: {
                    if let url = URL(string: "https://github.com/ruivza/speechdock") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                        Text("GitHub")
                    }
                    .font(.caption)
                }
                .buttonStyle(.link)

                Button(action: {
                    if let url = URL(string: "https://github.com/ruivza/speechdock/wiki") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "book")
                        Text("Documentation")
                    }
                    .font(.caption)
                }
                .buttonStyle(.link)
            }

            Divider()
                .frame(width: 200)

            // Original copyright: © 2026 Yoichiro Hasebe, preserved in LICENSE and NOTICE.
            // Credit the upstream author separately from fork maintenance.
            VStack(spacing: 6) {
                Text("Original author: Yoichiro Hasebe")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Button {
                        if let url = URL(string: "https://github.com/yohasebe/speechdock") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Original Project")
                    }
                    .buttonStyle(.link)

                    Button {
                        if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil) {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Apache License 2.0")
                    }
                    .buttonStyle(.link)
                }
                .font(.caption)

            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
