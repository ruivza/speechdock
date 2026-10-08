import Foundation
import Darwin
import Speech
@preconcurrency import AVFoundation

/// Error types for file transcription
enum FileTranscriptionError: LocalizedError {
    case fileNotFound
    case unsupportedFormat(String, supportedFormats: String)
    case fileTooLarge(maxMB: Int, actualMB: Int)
    case providerNotSupported(RealtimeSTTProvider)
    case readError(Error)
    case transcriptionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return NSLocalizedString("Audio file not found", comment: "File transcription error")
        case .unsupportedFormat(let format, let supportedFormats):
            return String(format: NSLocalizedString("Unsupported audio format: .%@\n\nSupported formats: %@", comment: "File transcription error"), format, supportedFormats)
        case .fileTooLarge(let maxMB, let actualMB):
            return String(format: NSLocalizedString("File too large (%dMB). Maximum size for this provider is %dMB", comment: "File transcription error"), actualMB, maxMB)
        case .providerNotSupported(let provider):
            return String(format: NSLocalizedString("%@ does not support file transcription.\n\nPlease switch to OpenAI, Gemini, ElevenLabs, or macOS (26+) provider.", comment: "Provider not supported for file transcription"), provider.rawValue)
        case .readError(let error):
            return String(format: NSLocalizedString("Failed to read audio file: %@", comment: "File transcription error"), error.localizedDescription)
        case .transcriptionFailed(let error):
            return String(format: NSLocalizedString("Transcription failed: %@", comment: "File transcription error"), error.localizedDescription)
        }
    }
}

/// Service for transcribing audio files
@MainActor
final class FileTranscriptionService {
    static let shared = FileTranscriptionService()

    /// Supported audio file extensions (union of all providers)
    private let supportedExtensions = Set(AudioFileSupport.extensions)

    private init() {}

    /// Validate and transcribe an audio file
    /// - Parameters:
    ///   - fileURL: URL of the audio file
    ///   - provider: STT provider to use
    ///   - language: Optional language code
    /// - Returns: Transcription result
    func transcribe(
        fileURL: URL,
        provider: RealtimeSTTProvider,
        language: String?
    ) async throws -> TranscriptionResult {
        // Keep the picker/drop grant alive for the entire asynchronous import.
        let scoped = fileURL.startAccessingSecurityScopedResource()
        defer { if scoped { fileURL.stopAccessingSecurityScopedResource() } }
        // Validate provider supports file transcription
        guard provider.supportsFileTranscription else {
            throw FileTranscriptionError.providerNotSupported(provider)
        }

        // Read and validate through the same descriptor.
        let audioData = try readAudioData(fileURL, for: provider)

        // Native APIs reopen URLs. Use a private snapshot of the validated bytes.
        if provider == .macOS {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("stt_file_\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: directory) }
            let snapshot = directory.appendingPathComponent("audio").appendingPathExtension(fileURL.pathExtension)
            try audioData.write(to: snapshot, options: .withoutOverwriting)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: snapshot.path)
            return try await transcribeWithMacOS(fileURL: snapshot, language: language)
        }

        // Get the appropriate STT model for the provider
        let model = defaultModel(for: provider)

        // Create API client and transcribe
        let client = apiClient(for: provider)

        do {
            return try await client.transcribe(
                audioData: audioData,
                model: model,
                language: language?.isEmpty == true ? nil : language,
                originalExtension: fileURL.pathExtension
            )
        } catch {
            throw FileTranscriptionError.transcriptionFailed(error)
        }
    }

    /// Validate file format and size for a specific provider
    /// - Parameters:
    ///   - url: File URL to validate
    ///   - provider: The provider to validate against
    func validateFile(_ url: URL, for provider: RealtimeSTTProvider) throws {
        let file = try openValidatedFile(url, for: provider)
        try? file.close()
    }

    /// Read through the checked descriptor with a hard cap, even if the file grows.
    func readAudioData(_ url: URL, for provider: RealtimeSTTProvider) throws -> Data {
        let file = try openValidatedFile(url, for: provider)
        defer { try? file.close() }
        let limit = provider.maxFileSizeMB * 1024 * 1024
        var data = Data()
        do {
            while data.count <= limit {
                let chunk = try file.read(upToCount: min(65_536, limit + 1 - data.count)) ?? Data()
                if chunk.isEmpty { break }
                data.append(chunk)
            }
        } catch {
            throw FileTranscriptionError.readError(error)
        }
        guard data.count <= limit else {
            throw FileTranscriptionError.fileTooLarge(maxMB: provider.maxFileSizeMB, actualMB: data.count / (1024 * 1024))
        }
        return data
    }

    private func openValidatedFile(_ url: URL, for provider: RealtimeSTTProvider) throws -> FileHandle {
        // Check extension
        let fileExtension = url.pathExtension.lowercased()
        guard supportedExtensions.contains(fileExtension) else {
            throw FileTranscriptionError.unsupportedFormat(fileExtension, supportedFormats: AudioFileSupport.formatHint)
        }

        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else {
            if errno == ENOENT { throw FileTranscriptionError.fileNotFound }
            throw FileTranscriptionError.readError(NSError(domain: NSPOSIXErrorDomain, code: Int(errno)))
        }
        let file = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0 else {
            let error = NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            try? file.close()
            throw FileTranscriptionError.readError(error)
        }
        guard metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            try? file.close()
            throw FileTranscriptionError.readError(NSError(domain: NSPOSIXErrorDomain, code: Int(EINVAL)))
        }
        guard metadata.st_size <= provider.maxFileSizeMB * 1024 * 1024 else {
            try? file.close()
            throw FileTranscriptionError.fileTooLarge(maxMB: provider.maxFileSizeMB, actualMB: Int(metadata.st_size / (1024 * 1024)))
        }
        return file
    }

    /// Get default STT model for file transcription
    private func defaultModel(for provider: RealtimeSTTProvider) -> STTModel {
        switch provider {
        case .openAI:
            return .whisper1  // whisper-1 is best for file transcription
        case .gemini:
            return .gemini25Flash
        case .elevenLabs:
            return .scribeV2
        case .grok, .macOS:
            // These don't support file transcription
            return .whisper1
        }
    }

    /// Create API client for provider
    private func apiClient(for provider: RealtimeSTTProvider) -> STTAPIClient {
        switch provider {
        case .openAI:
            return OpenAISTTClient()
        case .gemini:
            return GeminiSTTClient()
        case .elevenLabs:
            return ElevenLabsSTTClient()
        case .grok, .macOS:
            // Return OpenAI as fallback (shouldn't be called due to validation)
            return OpenAISTTClient()
        }
    }

    // MARK: - SpeechAnalyzer File Transcription (macOS 26+)

    // MARK: - macOS Native File Transcription

    /// Transcribe using macOS native speech recognition.
    /// On macOS 26+, tries SpeechAnalyzer first, falls back to SFSpeechRecognizer.
    /// On older macOS, uses SFSpeechRecognizer directly.
    private func transcribeWithMacOS(fileURL: URL, language: String?) async throws -> TranscriptionResult {
        let locale = self.locale(for: language)

        // Try SpeechAnalyzer first on macOS 26+
        #if compiler(>=6.1)
        if #available(macOS 26, *) {
            if let result = try await transcribeWithSpeechAnalyzerIfAvailable(fileURL: fileURL, locale: locale) {
                return result
            }
            // SpeechAnalyzer not available for this locale, fall through to SFSpeechRecognizer
        }
        #endif

        // Fallback: SFSpeechRecognizer with SFSpeechURLRecognitionRequest
        return try await transcribeWithSFSpeechRecognizer(fileURL: fileURL, locale: locale)
    }

    /// Build Locale from language code string
    private func locale(for language: String?) -> Locale {
        if let lang = language, !lang.isEmpty,
           let langCode = LanguageCode(rawValue: lang),
           let localeId = langCode.toLocaleIdentifier() {
            return Locale(identifier: localeId)
        }
        // Auto mode: use system locale directly
        // SFSpeechRecognizer accepts Locale.current; SpeechAnalyzer validates separately
        return Locale.current
    }

    // MARK: - SFSpeechRecognizer File Transcription (all macOS versions)

    /// Lock-guarded state for the SFSpeechRecognizer continuation.
    /// Guarantees the continuation is resumed exactly once, whether the
    /// recognition callback fires (possibly multiple times, on a background
    /// queue) or the surrounding task is cancelled first.
    private final class RecognitionTaskState: @unchecked Sendable {
        private let lock = NSLock()
        private var hasResumed = false
        private var task: SFSpeechRecognitionTask?
        private var continuation: CheckedContinuation<TranscriptionResult, Error>?

        func setContinuation(_ continuation: CheckedContinuation<TranscriptionResult, Error>) {
            lock.lock()
            self.continuation = continuation
            let alreadyResumed = hasResumed
            lock.unlock()
            // Cancellation won the race before the continuation existed
            if alreadyResumed {
                continuation.resume(throwing: CancellationError())
            }
        }

        func setTask(_ task: SFSpeechRecognitionTask) {
            lock.lock()
            self.task = task
            let alreadyResumed = hasResumed
            lock.unlock()
            if alreadyResumed {
                task.cancel()
            }
        }

        func resume(returning result: TranscriptionResult) {
            lock.lock()
            guard !hasResumed else {
                lock.unlock()
                return
            }
            hasResumed = true
            let continuation = self.continuation
            lock.unlock()
            continuation?.resume(returning: result)
        }

        func resume(throwing error: Error) {
            lock.lock()
            guard !hasResumed else {
                lock.unlock()
                return
            }
            hasResumed = true
            let continuation = self.continuation
            lock.unlock()
            continuation?.resume(throwing: error)
        }

        func cancel() {
            lock.lock()
            let task = self.task
            lock.unlock()
            task?.cancel()
            resume(throwing: CancellationError())
        }
    }

    /// Transcribe using SFSpeechURLRecognitionRequest with on-device recognition only.
    private func transcribeWithSFSpeechRecognizer(fileURL: URL, locale: Locale) async throws -> TranscriptionResult {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw FileTranscriptionError.transcriptionFailed(
                NSError(domain: "FileTranscription", code: -4, userInfo: [NSLocalizedDescriptionKey: "Speech recognition is not available for \(locale.identifier)"])
            )
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw FileTranscriptionError.transcriptionFailed(
                NSError(domain: "FileTranscription", code: -5, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("On-device speech recognition is unavailable for this language.", comment: "Offline speech recognition unavailable")])
            )
        }

        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true

        let state = RecognitionTaskState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                state.setContinuation(continuation)
                // Retain the task so cancellation can reach it (and it isn't deallocated mid-flight)
                state.setTask(recognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        state.resume(throwing: FileTranscriptionError.transcriptionFailed(error))
                        return
                    }
                    guard let result = result, result.isFinal else { return }
                    state.resume(returning: TranscriptionResult(text: result.bestTranscription.formattedString))
                })
            }
        } onCancel: {
            state.cancel()
        }
    }

    // MARK: - SpeechAnalyzer File Transcription (macOS 26+)

    #if compiler(>=6.1)
    /// Try SpeechAnalyzer transcription. Returns nil if model not available for the locale.
    @available(macOS 26, *)
    private func transcribeWithSpeechAnalyzerIfAvailable(fileURL: URL, locale: Locale) async throws -> TranscriptionResult? {
        // Resolve locale to one supported by SpeechTranscriber
        let resolvedLocale = await resolveLocaleForSpeechTranscriber(locale)

        let transcriber = SpeechTranscriber(
            locale: resolvedLocale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )

        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // Check if SpeechAnalyzer model is available for this locale
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            return nil  // Signal caller to use fallback
        }

        // Open audio file
        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: fileURL)
        } catch {
            throw FileTranscriptionError.readError(error)
        }

        let fileFormat = audioFile.processingFormat

        // Create audio converter if formats differ
        var converter: AVAudioConverter?
        if fileFormat != analyzerFormat {
            converter = AVAudioConverter(from: fileFormat, to: analyzerFormat)
            if converter == nil {
                return nil  // Can't convert, use fallback
            }
        }

        // Create AsyncStream to feed audio buffers to the analyzer
        let (inputSequence, continuation) = AsyncStream<AnalyzerInput>.makeStream()

        // Start results monitoring concurrently
        let resultsTask = Task<String, Error> {
            var accumulatedText = ""
            for try await result in transcriber.results {
                try Task.checkCancellation()

                var currentText = ""
                for char in result.text.characters {
                    currentText.append(char)
                }

                if result.isFinal && !currentText.isEmpty {
                    if accumulatedText.isEmpty {
                        accumulatedText = currentText
                    } else {
                        accumulatedText += " " + currentText
                    }
                }
            }
            return accumulatedText
        }

        // Start the analyzer with input sequence
        do {
            try await analyzer.start(inputSequence: inputSequence)
        } catch {
            resultsTask.cancel()
            continuation.finish()
            throw FileTranscriptionError.transcriptionFailed(error)
        }

        // Read and feed the audio file in chunks (off the main actor, so large
        // files don't block the UI)
        if let bufferError = await feedAudioToAnalyzer(
            audioFile: audioFile,
            analyzerFormat: analyzerFormat,
            converter: converter,
            continuation: continuation
        ) {
            resultsTask.cancel()
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
            throw bufferError is FileTranscriptionError ? bufferError : FileTranscriptionError.transcriptionFailed(bufferError)
        }

        // Wait for analyzer to finalize
        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
        } catch {
            resultsTask.cancel()
            throw FileTranscriptionError.transcriptionFailed(error)
        }

        // Wait for results
        let fullText: String
        do {
            fullText = try await resultsTask.value
        } catch is CancellationError {
            throw FileTranscriptionError.transcriptionFailed(
                NSError(domain: "FileTranscription", code: -1, userInfo: [NSLocalizedDescriptionKey: "Transcription cancelled"])
            )
        } catch {
            throw FileTranscriptionError.transcriptionFailed(error)
        }

        return TranscriptionResult(text: fullText)
    }

    /// Read the audio file in chunks and feed (converted) buffers to the analyzer.
    /// Runs off the main actor so the synchronous AVAudioFile.read loop doesn't
    /// block the UI on large files. Always finishes the input stream; returns
    /// the error that stopped the loop, if any.
    @available(macOS 26, *)
    nonisolated private func feedAudioToAnalyzer(
        audioFile: AVAudioFile,
        analyzerFormat: AVAudioFormat,
        converter: AVAudioConverter?,
        continuation: AsyncStream<AnalyzerInput>.Continuation
    ) async -> Error? {
        let fileFormat = audioFile.processingFormat
        let totalFrames = AVAudioFrameCount(audioFile.length)
        let bufferSize: AVAudioFrameCount = 4096
        var framesRead: AVAudioFrameCount = 0
        var bufferError: Error?

        // Signal end of input no matter how the loop exits
        defer { continuation.finish() }

        while framesRead < totalFrames {
            if Task.isCancelled {
                bufferError = CancellationError()
                break
            }

            let framesToRead = min(bufferSize, totalFrames - framesRead)
            guard let readBuffer = AVAudioPCMBuffer(pcmFormat: fileFormat, frameCapacity: framesToRead) else {
                bufferError = FileTranscriptionError.readError(
                    NSError(domain: "FileTranscription", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate audio buffer"])
                )
                break
            }

            do {
                try audioFile.read(into: readBuffer, frameCount: framesToRead)
            } catch {
                bufferError = FileTranscriptionError.readError(error)
                break
            }

            // Convert if needed
            let bufferToSend: AVAudioPCMBuffer
            if let converter = converter {
                let sampleRateRatio = analyzerFormat.sampleRate / fileFormat.sampleRate
                let outputFrameCapacity = AVAudioFrameCount(Double(readBuffer.frameLength) * sampleRateRatio)
                guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: outputFrameCapacity) else {
                    bufferError = FileTranscriptionError.readError(
                        NSError(domain: "FileTranscription", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate conversion buffer"])
                    )
                    break
                }

                var convertError: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return readBuffer
                }
                converter.convert(to: outputBuffer, error: &convertError, withInputFrom: inputBlock)

                if let convertError = convertError {
                    bufferError = FileTranscriptionError.readError(convertError)
                    break
                }
                bufferToSend = outputBuffer
            } else {
                bufferToSend = readBuffer
            }

            let input = AnalyzerInput(buffer: bufferToSend)
            continuation.yield(input)

            framesRead += framesToRead
        }

        return bufferError
    }

    /// Resolve a locale to one supported by SpeechTranscriber.
    /// If the given locale is already supported, returns it as-is.
    /// Otherwise, finds the best match from supported locales by language code.
    @available(macOS 26, *)
    private func resolveLocaleForSpeechTranscriber(_ locale: Locale) async -> Locale {
        let supported = await SpeechTranscriber.supportedLocales
        let langCode = locale.language.languageCode?.identifier ?? "en"

        // Check if exact locale is supported
        if supported.contains(where: { $0.identifier == locale.identifier }) {
            return locale
        }

        // Find match by language+region
        if let region = locale.region?.identifier,
           let match = supported.first(where: {
               $0.language.languageCode?.identifier == langCode &&
               $0.region?.identifier == region
           }) {
            return match
        }

        // Find match by language only
        if let match = supported.first(where: {
            $0.language.languageCode?.identifier == langCode
        }) {
            return match
        }

        return Locale(identifier: "en-US")
    }
    #endif
}
