import AppKit

@MainActor
enum WindowPresentation {
    static func alert(_ alert: NSAlert, parent: NSWindow? = nil,
                      completion: @escaping (NSApplication.ModalResponse) -> Void = { _ in }) {
        if let parent = parent ?? NSApp.keyWindow ?? NSApp.mainWindow {
            alert.beginSheetModal(for: parent, completionHandler: completion)
        } else {
            completion(alert.runModal())
        }
    }

    static func panel(_ panel: NSSavePanel, parent: NSWindow? = nil,
                      completion: @escaping (NSApplication.ModalResponse) -> Void) {
        if let parent = parent ?? NSApp.keyWindow ?? NSApp.mainWindow {
            panel.beginSheetModal(for: parent, completionHandler: completion)
        } else {
            panel.begin(completionHandler: completion)
        }
    }
}
