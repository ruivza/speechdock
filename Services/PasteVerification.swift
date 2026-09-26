import AppKit
import ApplicationServices

@MainActor
struct PasteVerification {
    let pid: pid_t
    let element: AXUIElement
    let expected: String

    static func expectedText(original: String, selection: NSRange, inserted: String) -> String? {
        let value = original as NSString
        guard selection.location != NSNotFound, selection.location >= 0, selection.length >= 0,
              selection.location <= value.length, selection.length <= value.length - selection.location else { return nil }
        return value.replacingCharacters(in: selection, with: inserted)
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func capture(inserting text: String) -> Self? {
        guard let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != getpid(),
              let focused = attribute(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedUIElementAttribute),
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        guard let original = attribute(element, kAXValueAttribute) as? String,
              let selectionValue = attribute(element, kAXSelectedTextRangeAttribute),
              CFGetTypeID(selectionValue) == AXValueGetTypeID() else { return nil }
        var selection = CFRange()
        guard AXValueGetValue(selectionValue as! AXValue, .cfRange, &selection),
              let expected = expectedText(original: original, selection: NSRange(location: selection.location, length: selection.length), inserted: text),
              expected != original else { return nil }
        return Self(pid: app.processIdentifier, element: element, expected: expected)
    }

    var isConfirmed: Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
              let focused = Self.attribute(AXUIElementCreateApplication(pid), kAXFocusedUIElementAttribute),
              CFEqual(focused, element) else { return false }
        return Self.attribute(element, kAXValueAttribute) as? String == expected
    }
}

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
        panel.title = NSLocalizedString("Copied to Clipboard", comment: "Unverified paste status")
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        let label = NSTextField(wrappingLabelWithString: NSLocalizedString("Paste could not be verified. You can paste the copied text manually.", comment: "Unverified paste guidance"))
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
