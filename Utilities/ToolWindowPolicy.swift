import AppKit

/// Tools appear on the active Space when explicitly opened. They remain there
/// while the user changes Spaces and can accompany another app in full screen.
enum ToolWindowPolicy {
    // Editable panels activate the app and use a normal desktop Space.
    static let inputPanel: NSWindow.CollectionBehavior = [.moveToActiveSpace, .fullScreenNone]
    static let currentSpace: NSWindow.CollectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
}
