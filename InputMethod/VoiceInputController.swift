import AppKit
import AVFoundation
import Carbon
import InputMethodKit

@MainActor
@objc(SpeechDockVoiceInputController)
final class VoiceInputController: IMKInputController {
    private static weak var activeController: VoiceInputController?
    private var active = false
    private let recording = VoiceInputSession()

    override func activateServer(_ sender: Any!) {
        Self.activeController?.cancelRecording()
        Self.activeController = self
        active = true
        super.activateServer(sender)
    }

    override func deactivateServer(_ sender: Any!) {
        active = false
        cancelRecording()
        if Self.activeController === self { Self.activeController = nil }
        super.deactivateServer(sender)
    }

    override func inputControllerWillClose() {
        active = false
        cancelRecording()
        if Self.activeController === self { Self.activeController = nil }
        super.inputControllerWillClose()
    }

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue |
            NSEvent.EventTypeMask.leftMouseDown.rawValue |
            NSEvent.EventTypeMask.rightMouseDown.rawValue |
            NSEvent.EventTypeMask.otherMouseDown.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, active, Self.activeController === self else { return false }
        guard !IsSecureEventInputEnabled() else { cancelRecording(); return false }
        guard event.type == .keyDown else { cancelRecording(); return false }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if event.keyCode == 15, modifiers == [.control, .option] { // R
            if !event.isARepeat { toggleRecording() }
            return true
        }
        if event.keyCode == 53, recording.phase != .idle { // Escape
            cancelRecording()
            return true
        }
        // Typing or moving the caret ends this recording before the event is passed on.
        if recording.phase != .idle { cancelRecording() }
        return false
    }

    override func commitComposition(_ sender: Any!) {
        // A client requesting an immediate end must not receive a delayed async result.
        cancelRecording()
    }

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("Start / Finish Voice Input (⌃⌥R)", comment: "Voice input menu"),
                     action: #selector(toggleVoiceInput(_:)), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("Cancel Voice Input", comment: "Voice input menu"), action: #selector(cancelVoiceInput(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: NSLocalizedString("Voice Input Settings…", comment: "Voice input menu"), action: #selector(showPreferences(_:)), keyEquivalent: "")
        return menu
    }

    @objc private func toggleVoiceInput(_ sender: Any!) { toggleRecording() }
    @objc private func cancelVoiceInput(_ sender: Any!) { cancelRecording() }

    override func showPreferences(_ sender: Any!) {
        cancelRecording()
        VoiceInputInterface.shared.showPreferences()
    }

    private func toggleRecording() {
        switch recording.phase {
        case .listening: recording.finish()
        case .preparing: cancelRecording()
        case .finishing: break
        case .idle: startRecording()
        }
    }

    private func startRecording() {
        guard active, Self.activeController === self, !IsSecureEventInputEnabled(),
              let destination = client() else { return }
        let selection = destination.selectedRange()
        // Fail closed when the host cannot report a usable insertion position.
        guard selection.location != NSNotFound else { return }
        let service = OnDeviceSTTFactory.makeService()
        service.selectedLanguage = VoiceInputInterface.selectedLanguage
        recording.onUpdate = { [weak self] message in
            guard let self, Self.activeController === self else { return }
            VoiceInputInterface.shared.showStatus(message)
        }
        recording.start(using: service, authorize: {
            await AVCaptureDevice.requestAccess(for: .audio)
        }, canCommit: { [weak self] in
            guard let self, self.active, Self.activeController === self,
                  !IsSecureEventInputEnabled(), let current = self.client() else { return false }
            return (current as AnyObject) === (destination as AnyObject) &&
                NSEqualRanges(destination.selectedRange(), selection)
        }, commit: { text in
            destination.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
        })
    }

    private func cancelRecording() {
        recording.cancel()
        if Self.activeController === self { VoiceInputInterface.shared.showStatus("") }
    }
}
