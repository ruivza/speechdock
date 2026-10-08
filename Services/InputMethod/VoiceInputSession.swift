import Foundation

/// Owns one recording and its destination. Stale callbacks can never commit text.
@MainActor
final class VoiceInputSession: RealtimeSTTDelegate {
    enum Phase: Equatable { case idle, preparing, listening, finishing }
    private(set) var phase: Phase = .idle
    private(set) var text = ""
    var onUpdate: ((String) -> Void)?

    private var generation = UUID()
    private var service: RealtimeSTTService?
    private var work: Task<Void, Never>?
    private var timeout: Task<Void, Never>?
    private var canCommit: (() -> Bool)?
    private var commit: ((String) -> Void)?
    private let maximumCharacters = 100_000

    @discardableResult
    func start(using service: RealtimeSTTService,
               authorize: @escaping () async -> Bool,
               canCommit: @escaping () -> Bool,
               commit: @escaping (String) -> Void) -> Task<Void, Never> {
        cancel()
        let token = generation
        self.service = service
        self.canCommit = canCommit
        self.commit = commit
        service.delegate = self
        phase = .preparing
        onUpdate?(NSLocalizedString("Preparing speech recognition…", comment: "Voice input status"))
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                let authorized = await authorize()
                try Task.checkCancellation()
                guard self.generation == token, canCommit() else {
                    if self.generation == token { self.cancel() }
                    return
                }
                guard authorized else {
                    throw RealtimeSTTError.permissionDenied(NSLocalizedString("Allow microphone access in System Settings, then try again.", comment: "Voice input status"))
                }
                try await service.startListening()
                try Task.checkCancellation()
                guard self.generation == token, canCommit(), service.isListening else {
                    service.delegate = nil
                    service.stopListening()
                    if self.generation == token { self.cancel() }
                    return
                }
                self.phase = .listening
                self.onUpdate?(NSLocalizedString("Listening — ⌃⌥R to insert, Esc to cancel", comment: "Voice input status"))
                // Do not leave the microphone running indefinitely after a lost event.
                self.timeout = Task { [weak self] in
                    do { try await Task.sleep(nanoseconds: 300_000_000_000) }
                    catch { return }
                    guard let self, self.generation == token else { return }
                    self.cancel()
                    self.onUpdate?(NSLocalizedString("Recording cancelled after five minutes.", comment: "Voice input status"))
                }
            } catch {
                service.delegate = nil
                service.stopListening()
                guard self.generation == token else { return }
                self.cancel()
                if !(error is CancellationError) { self.onUpdate?(error.localizedDescription) }
            }
        }
        work = task
        return task
    }

    @discardableResult
    func finish() -> Task<Void, Never>? {
        guard phase == .listening, let service else { return nil }
        phase = .finishing
        timeout?.cancel()
        timeout = nil
        let token = generation
        onUpdate?(NSLocalizedString("Finishing speech recognition…", comment: "Voice input status"))
        let task = Task { [weak self] in
            await service.finishListening()
            guard let self, !Task.isCancelled, self.generation == token else { return }
            let result = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let destinationIsValid = self.canCommit?() == true
            let commit = self.commit
            // Invalidate before calling the client: insertText can reenter the controller.
            self.cancel()
            if destinationIsValid, !result.isEmpty {
                commit?(result)
            } else if !destinationIsValid {
                self.onUpdate?(NSLocalizedString("Input destination changed. Recording cancelled.", comment: "Voice input status"))
            } else {
                self.onUpdate?(NSLocalizedString("No speech recognized.", comment: "Voice input status"))
            }
        }
        work = task
        return task
    }

    func cancel() {
        generation = UUID()
        work?.cancel()
        timeout?.cancel()
        work = nil
        timeout = nil
        let oldService = service
        service = nil
        oldService?.delegate = nil
        oldService?.stopListening()
        canCommit = nil
        commit = nil
        text = ""
        phase = .idle
        onUpdate?("")
    }

    private func accepts(_ service: RealtimeSTTService) -> Bool {
        self.service === service && phase != .idle
    }

    private func receive(_ text: String, from service: RealtimeSTTService) {
        guard accepts(service) else { return }
        guard text.count <= maximumCharacters else {
            cancel()
            onUpdate?(NSLocalizedString("Recording exceeded the text limit and was cancelled.", comment: "Voice input status"))
            return
        }
        // Both native recognizers deliver the complete transcript for this session.
        self.text = text
    }

    func realtimeSTT(_ service: RealtimeSTTService, didReceivePartialResult text: String) {
        receive(text, from: service)
    }
    func realtimeSTT(_ service: RealtimeSTTService, didReceiveFinalResult text: String) {
        receive(text, from: service)
    }
    func realtimeSTT(_ service: RealtimeSTTService, didFailWithError error: Error) {
        guard accepts(service) else { return }
        cancel()
        onUpdate?(error.localizedDescription)
    }
    func realtimeSTT(_ service: RealtimeSTTService, didChangeListeningState isListening: Bool) {
        guard accepts(service), !isListening, phase == .listening else { return }
        finish()
    }
    func realtimeSTT(_ service: RealtimeSTTService, didUpdatePreparation message: String?) {
        guard accepts(service), phase == .preparing, let message else { return }
        onUpdate?(message)
    }
}
