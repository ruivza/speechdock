import AppKit

/// Supported formats and decoding rules shared by the drop target and its hints.
enum TextFileImport {
    static let extensions = ["txt", "md", "text", "rtf"]
    static var extensionHint: String { extensions.map { "." + $0 }.joined(separator: ", ") }
    static let maximumBytes = 1_048_576

    enum ImportError: LocalizedError {
        case unsupported, tooLarge, invalidText
        var errorDescription: String? {
            switch self {
            case .unsupported:
                return String(format: NSLocalizedString("Supported text files: %@", comment: "File import formats"), TextFileImport.extensionHint)
            case .tooLarge:
                return NSLocalizedString("Maximum file size is 1MB.", comment: "File import size limit")
            case .invalidText:
                return NSLocalizedString("The file could not be read as text. Save plain text as UTF-8, or use a valid RTF file.", comment: "File import decoding error")
            }
        }
    }

    static func read(_ url: URL) throws -> String {
        guard url.isFileURL, extensions.contains(url.pathExtension.lowercased()) else {
            throw ImportError.unsupported
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let data = try file.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else { throw ImportError.tooLarge }
        if url.pathExtension.lowercased() == "rtf" {
            guard let text = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) else {
                throw ImportError.invalidText
            }
            return text.string
        }
        guard let text = String(data: data, encoding: .utf8), !text.contains("\0") else {
            throw ImportError.invalidText
        }
        return text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    }
}
