import AppKit
import Darwin

enum InputMethodInstallationService {
    enum InstallationError: LocalizedError {
        case missingComponent, invalidDirectory, alreadyInstalled
        var errorDescription: String? {
            switch self {
            case .missingComponent: return NSLocalizedString("The voice input component is missing or invalid. Rebuild or reinstall SpeechDock.", comment: "Voice input installation")
            case .invalidDirectory: return NSLocalizedString("The Input Methods directory must be owned by this user, not a symbolic link, and not writable by other users.", comment: "Voice input installation")
            case .alreadyInstalled: return NSLocalizedString("SpeechDock Voice Input is already installed. To update it, switch to another input source, remove the old component from ~/Library/Input Methods in Finder, then install again and log out.", comment: "Voice input installation")
            }
        }
    }

    /// Copy without elevated privileges or overwriting another installed component.
    static func install(component: URL, in directory: URL) throws -> URL {
        let manager = FileManager.default
        let componentValues = try component.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard component.lastPathComponent == "SpeechDockVoiceInput.app",
              componentValues.isDirectory == true, componentValues.isSymbolicLink != true,
              let bundle = Bundle(url: component),
              ["com.speechdock.inputmethod.voice", "com.speechdock.inputmethod.voice.dev"].contains(bundle.bundleIdentifier),
              let executable = bundle.executableURL, manager.isExecutableFile(atPath: executable.path) else {
            throw InstallationError.missingComponent
        }
        if let values = try? directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) {
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw InstallationError.invalidDirectory
            }
        } else {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        }
        let attributes = try manager.attributesOfItem(atPath: directory.path)
        guard (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              let permissions = attributes[.posixPermissions] as? NSNumber,
              permissions.intValue & 0o022 == 0 else {
            throw InstallationError.invalidDirectory
        }
        let destination = directory.appendingPathComponent(component.lastPathComponent, isDirectory: true)
        // resourceValues also detects dangling links; moveItem below never replaces.
        if (try? destination.resourceValues(forKeys: [.isSymbolicLinkKey])) != nil {
            throw InstallationError.alreadyInstalled
        }
        let staging = directory.appendingPathComponent(".speechdock-\(UUID().uuidString).app", isDirectory: true)
        defer { try? manager.removeItem(at: staging) }
        try manager.copyItem(at: component, to: staging)
        try manager.moveItem(at: staging, to: destination)
        return destination
    }

    @MainActor
    static func presentSetup() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Set Up Voice Input Method…", comment: "Input method setup")
        alert.informativeText = NSLocalizedString("Choose your ~/Library/Input Methods folder to install SpeechDock Voice Input, then add it under System Settings → Keyboard → Text Input → Edit → + → English. Recognition runs locally without Accessibility permission. Select it and press ⌃⌥R to start/finish; Esc cancels.", comment: "Voice input installation")
        alert.addButton(withTitle: NSLocalizedString("Install", comment: "Voice input installation"))
        alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Voice input installation"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            guard let resources = Bundle.main.resourceURL else { throw InstallationError.missingComponent }
            let component = resources.appendingPathComponent("InputMethods/SpeechDockVoiceInput.app", isDirectory: true)
            // The system picker grants access to exactly the installation directory.
            // getpwuid is used only to suggest the real home folder outside the container.
            guard let user = getpwuid(getuid()), let homePath = user.pointee.pw_dir else {
                throw InstallationError.invalidDirectory
            }
            let home = URL(fileURLWithPath: String(cString: homePath), isDirectory: true)
            let expected = home.appendingPathComponent("Library/Input Methods", isDirectory: true)
            let picker = NSOpenPanel()
            picker.title = NSLocalizedString("Choose your Input Methods folder", comment: "Voice input installation")
            picker.message = NSLocalizedString("Choose ~/Library/Input Methods. Create the folder here if needed.", comment: "Voice input installation")
            picker.prompt = NSLocalizedString("Install Here", comment: "Voice input installation")
            picker.canChooseDirectories = true
            picker.canChooseFiles = false
            picker.allowsMultipleSelection = false
            picker.canCreateDirectories = true
            picker.directoryURL = expected
            guard picker.runModal() == .OK, let directory = picker.url else { return }
            guard directory.standardizedFileURL == expected.standardizedFileURL else {
                throw InstallationError.invalidDirectory
            }
            let scoped = directory.startAccessingSecurityScopedResource()
            defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
            _ = try install(component: component, in: directory)
            let result = NSAlert()
            result.messageText = NSLocalizedString("SpeechDock Voice Input installed", comment: "Voice input installation")
            result.informativeText = NSLocalizedString("Add it in Keyboard → Text Input → Edit → + → English. If it is not listed, log out and back in. Choose Voice Input Settings… in the input menu to set the speech language.", comment: "Voice input installation")
            result.addButton(withTitle: NSLocalizedString("Open Keyboard Settings", comment: "Voice input installation"))
            result.addButton(withTitle: NSLocalizedString("Done", comment: "Voice input installation"))
            if result.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        } catch {
            let failure = NSAlert()
            failure.messageText = NSLocalizedString("Voice input installation failed", comment: "Voice input installation")
            failure.informativeText = error.localizedDescription
            failure.runModal()
        }
    }
}
