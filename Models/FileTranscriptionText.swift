import Foundation

enum FileTranscriptionText {
    static func appending(_ result: String, to existing: String) -> String? {
        let text = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        guard !existing.isEmpty else { return text }
        return existing + (existing.hasSuffix("\n") ? "" : "\n") + text
    }
}
