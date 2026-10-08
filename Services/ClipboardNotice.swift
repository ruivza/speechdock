import AppKit

@MainActor
final class ClipboardNotice {
    static let shared = ClipboardNotice()
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    func showCopied() {
        dismissTask?.cancel()
        panel?.orderOut(nil)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 70),
                            styleMask: [.nonactivatingPanel, .titled], backing: .buffered, defer: false)
        panel.title = NSLocalizedString("Copied to Clipboard", comment: "Clipboard copy status")
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        let label = NSTextField(wrappingLabelWithString: NSLocalizedString("Text copied. Paste manually, or use SpeechDock Voice Input for direct dictation.", comment: "Manual paste guidance"))
        label.frame = NSRect(x: 16, y: 12, width: 368, height: 46)
        panel.contentView?.addSubview(label)
        panel.center()
        panel.orderFrontRegardless()
        self.panel = panel
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
            self?.panel = nil
        }
    }
}
