import Foundation

/// Keeps trailing results alive until a provider has finished its stop handshake.
@MainActor
final class STTFinalization: RealtimeSTTDelegate {
    private(set) var text: String
    init(text: String) { self.text = text }

    static func finish(_ service: RealtimeSTTService, initialText: String) async -> String {
        let collector = STTFinalization(text: initialText)
        service.delegate = collector
        await service.finishListening()
        service.delegate = nil
        return collector.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func realtimeSTT(_ service: RealtimeSTTService, didReceivePartialResult text: String) { self.text = text }
    func realtimeSTT(_ service: RealtimeSTTService, didReceiveFinalResult text: String) { self.text = text }
    func realtimeSTT(_ service: RealtimeSTTService, didFailWithError error: Error) {}
    func realtimeSTT(_ service: RealtimeSTTService, didChangeListeningState isListening: Bool) {}
}
