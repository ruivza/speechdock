import AppKit

// MARK: - Copy to Clipboard Command

class CopyToClipboardCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let text = directParameter as? String, !text.isEmpty else {
            setAppleScriptError(.clipboardEmptyText, message: "Cannot copy empty text. Provide a non-empty string.")
            return nil
        }

        suspendExecution()

        Task { @MainActor in
            // Wait for app initialization
            let initialized = await self.waitForInitialization(timeout: 5.0)
            guard initialized else {
                self.setAppleScriptError(.appNotInitialized,
                    message: "SpeechDock is still initializing. Please try again in a moment.")
                self.resumeExecution(withResult: nil)
                return
            }

            ClipboardService.shared.copyToClipboard(text)
            self.resumeExecution(withResult: nil)
        }

        return nil
    }
}

// MARK: - Paste Text Command

class PasteTextCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let text = directParameter as? String, !text.isEmpty else {
            setAppleScriptError(.clipboardEmptyText, message: "Cannot paste empty text. Provide a non-empty string.")
            return nil
        }

        suspendExecution()

        Task { @MainActor in
            // Wait for app initialization
            let initialized = await self.waitForInitialization(timeout: 5.0)
            guard initialized else {
                self.setAppleScriptError(.appNotInitialized,
                    message: "SpeechDock is still initializing. Please try again in a moment.")
                self.resumeExecution(withResult: nil)
                return
            }

            let verified = await ClipboardService.shared.copyAndPaste(text)
            if !verified && NSPasteboard.general.string(forType: .string) != text {
                self.scriptErrorNumber = -10000
                self.scriptErrorString = "Could not copy the text to the clipboard."
                self.resumeExecution(withResult: nil)
            } else {
                self.resumeExecution(withResult: verified ? "inserted" : "copied to clipboard")
            }
        }

        return nil
    }
}
