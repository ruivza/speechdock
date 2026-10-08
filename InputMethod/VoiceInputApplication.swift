import AppKit
import InputMethodKit

@main
enum VoiceInputApplication {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = VoiceInputApplicationDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
private final class VoiceInputApplicationDelegate: NSObject, NSApplicationDelegate {
    private var server: IMKServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let identifier = Bundle.main.bundleIdentifier,
              let connection = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String else {
            NSApplication.shared.terminate(nil)
            return
        }
        server = IMKServer(name: connection, bundleIdentifier: identifier)
    }
}
