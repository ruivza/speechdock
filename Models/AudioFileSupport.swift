import Foundation
import UniformTypeIdentifiers

/// Shared by validation, file chooser, drag destinations, and format guidance.
enum AudioFileSupport {
    static let extensions = ["mp3", "wav", "m4a", "aac", "aiff", "aif", "webm", "ogg", "flac", "mp4"]
    static var contentTypes: [UTType] { extensions.compactMap { UTType(filenameExtension: $0) } }
    static var formatHint: String { extensions.map { $0.uppercased() }.joined(separator: ", ") }
    static func accepts(_ url: URL) -> Bool { extensions.contains(url.pathExtension.lowercased()) }
    static func limits(for provider: RealtimeSTTProvider) -> String {
        if provider == .macOS {
            return NSLocalizedString("Maximum 100 MB · No duration limit", comment: "Local audio file limits")
        }
        return String(format: NSLocalizedString("Maximum %d MB · Duration: %@", comment: "Audio file limits"), provider.maxFileSizeMB, NSLocalizedString(provider.maxAudioDuration, comment: "Audio duration limit"))
    }
}
