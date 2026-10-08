import AppKit

final class ClipboardService {
    static let shared = ClipboardService()

    /// Lock to prevent concurrent clipboard operations
    private let clipboardLock = NSLock()

    /// Maximum time to wait for clipboard operations (seconds)
    private let maxWaitTime: TimeInterval = 0.5

    private init() {}

    /// Copy text to clipboard with thread safety
    func copyToClipboard(_ text: String) {
        clipboardLock.lock()
        defer { clipboardLock.unlock() }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Clipboard State Preservation

    /// Represents saved clipboard state for restoration
    struct ClipboardState {
        let changeCount: Int
        let items: [NSPasteboardItem]

        init(pasteboard: NSPasteboard) {
            self.changeCount = pasteboard.changeCount
            // Deep copy pasteboard items to preserve their content
            self.items = pasteboard.pasteboardItems?.compactMap { item -> NSPasteboardItem? in
                let newItem = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) {
                        newItem.setData(data, forType: type)
                    }
                }
                return newItem.types.isEmpty ? nil : newItem
            } ?? []
        }
    }

    /// Save current clipboard state
    func saveClipboardState() -> ClipboardState {
        clipboardLock.lock()
        defer { clipboardLock.unlock() }
        return ClipboardState(pasteboard: NSPasteboard.general)
    }

    /// Restore clipboard state if it hasn't been modified by another app
    /// Returns true if restoration was performed, false if clipboard was modified externally
    @discardableResult
    func restoreClipboardState(_ state: ClipboardState) -> Bool {
        clipboardLock.lock()
        defer { clipboardLock.unlock() }

        let pasteboard = NSPasteboard.general

        // Check if clipboard was modified by another app since our operation
        // If changeCount increased by more than 1, another app wrote to clipboard
        let changesSinceOurOperation = pasteboard.changeCount - state.changeCount
        if changesSinceOurOperation > 2 {
            // Another app modified the clipboard, don't overwrite their content
            dprint("ClipboardService: Skipping restore - clipboard modified by another app (changes: \(changesSinceOurOperation))")

            return false
        }

        // Restore the original content
        pasteboard.clearContents()
        if !state.items.isEmpty {
            pasteboard.writeObjects(state.items)
        }

        return true
    }
}
