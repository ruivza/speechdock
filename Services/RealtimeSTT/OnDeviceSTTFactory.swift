import Foundation

/// Shared by the main app and the sandboxed input method. No cloud fallback.
enum OnDeviceSTTFactory {
    @MainActor
    static func makeService() -> RealtimeSTTService {
        #if compiler(>=6.1)
        if #available(macOS 26, *) { return SpeechAnalyzerSTT() }
        #endif
        return MacOSRealtimeSTT()
    }
}
