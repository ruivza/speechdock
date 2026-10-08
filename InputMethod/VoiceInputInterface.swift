import AppKit

/// UI only: it never changes focus while recording or stores recognized text.
@MainActor
final class VoiceInputInterface: NSObject {
    static let shared = VoiceInputInterface()
    private let status = NSTextField(wrappingLabelWithString: "")
    private var panel: NSPanel?
    private var preferences: NSWindow?
    private var languages: [LanguageCode] = []
    private var languagePicker: NSPopUpButton?
    private var interfacePicker: NSPopUpButton?

    static var selectedLanguage: String {
        UserDefaults.standard.string(forKey: "voiceInputLanguage") ?? LanguageCode.english.rawValue
    }

    func showStatus(_ message: String) {
        guard !message.isEmpty else { panel?.orderOut(nil); return }
        if panel == nil {
            let window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 440, height: 70),
                                 styleMask: [.nonactivatingPanel, .titled], backing: .buffered, defer: false)
            window.title = NSLocalizedString("SpeechDock Voice Input", comment: "Voice input interface")
            window.level = .floating
            window.hidesOnDeactivate = false
            window.isFloatingPanel = true
            window.becomesKeyOnlyIfNeeded = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            status.frame = NSRect(x: 16, y: 12, width: 408, height: 46)
            window.contentView?.addSubview(status)
            window.center()
            panel = window
        }
        status.stringValue = message
        panel?.orderFrontRegardless()
    }

    func showPreferences() {
        showStatus("")
        if preferences == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = NSLocalizedString("SpeechDock Voice Input Settings", comment: "Voice input interface")
            window.isReleasedWhenClosed = false
            let instructions = NSTextField(wrappingLabelWithString:
                NSLocalizedString("Select SpeechDock Voice Input in the macOS input menu. Press ⌃⌥R to start, then press it again to insert the result. Esc cancels. Changing the input destination cancels the recording.\n\nRecognition runs on-device. Unsupported languages fail without cloud fallback. Apple may download language models. Recordings and transcripts are not saved.", comment: "Voice input interface"))
            instructions.frame = NSRect(x: 20, y: 135, width: 480, height: 185)
            window.contentView?.addSubview(instructions)
            let label = NSTextField(labelWithString: NSLocalizedString("Speech language:", comment: "Voice input interface"))
            label.frame = NSRect(x: 20, y: 102, width: 160, height: 24)
            window.contentView?.addSubview(label)
            languages = LanguageCode.macOSAvailableLanguages()
            if languages.isEmpty { languages = [.english] }
            let picker = NSPopUpButton(frame: NSRect(x: 180, y: 98, width: 320, height: 30))
            picker.addItems(withTitles: languages.map { $0.displayName })
            picker.selectItem(at: languages.firstIndex(where: { $0.rawValue == Self.selectedLanguage }) ?? 0)
            picker.target = self
            picker.action = #selector(changeLanguage(_:))
            window.contentView?.addSubview(picker)
            languagePicker = picker
            let interfaceLabel = NSTextField(labelWithString: NSLocalizedString("Interface Language", comment: "Interface language"))
            interfaceLabel.frame = NSRect(x: 20, y: 64, width: 160, height: 24)
            window.contentView?.addSubview(interfaceLabel)
            let interfacePicker = NSPopUpButton(frame: NSRect(x: 180, y: 60, width: 320, height: 30))
            interfacePicker.addItems(withTitles: InterfaceLanguage.allCases.map(\.displayName))
            let selectedInterface = InterfaceLanguage(rawValue: UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "") ?? .system
            interfacePicker.selectItem(at: InterfaceLanguage.allCases.firstIndex(of: selectedInterface) ?? 0)
            interfacePicker.target = self
            interfacePicker.action = #selector(changeInterfaceLanguage(_:))
            window.contentView?.addSubview(interfacePicker)
            self.interfacePicker = interfacePicker
            let restartHint = NSTextField(wrappingLabelWithString: NSLocalizedString("Log out and back in to apply the input method interface language.", comment: "Input method language restart"))
            restartHint.font = .systemFont(ofSize: 11)
            restartHint.textColor = .secondaryLabelColor
            restartHint.frame = NSRect(x: 20, y: 15, width: 480, height: 38)
            window.contentView?.addSubview(restartHint)
            preferences = window
            window.center()
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        preferences?.makeKeyAndOrderFront(nil)
    }

    @objc private func changeLanguage(_ sender: NSPopUpButton) {
        guard languages.indices.contains(sender.indexOfSelectedItem) else { return }
        UserDefaults.standard.set(languages[sender.indexOfSelectedItem].rawValue, forKey: "voiceInputLanguage")
    }

    @objc private func changeInterfaceLanguage(_ sender: NSPopUpButton) {
        guard InterfaceLanguage.allCases.indices.contains(sender.indexOfSelectedItem) else { return }
        InterfaceLanguage.allCases[sender.indexOfSelectedItem].apply()
    }
}
