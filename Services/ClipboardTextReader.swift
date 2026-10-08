import AppKit

/// Reads text the user has copied, without accessing other applications.
@MainActor
final class ClipboardTextReader {
    static let shared = ClipboardTextReader()
    private let htmlType = NSPasteboard.PasteboardType.html
    private init() {}

    /// Read the best available text representation from the pasteboard.
    /// Picks whichever format best preserves paragraph breaks (blank lines):
    /// - If plain text already contains blank lines, use it directly
    ///   (TextEdit, Pages, Notes, and many native apps put structure-preserving plain text)
    /// - Otherwise try HTML with <br><br> injection (web browsers)
    /// - Otherwise try RTF via attributed string walk
    /// - Otherwise return plain text as last resort
    /// Returns nil if the pasteboard has no readable text.
    func readBestTextFromPasteboard(_ pasteboard: NSPasteboard = .general) -> String? {
        let plainText = pasteboard.string(forType: .string)

        // 1. If plain text already preserves paragraph structure (has blank lines),
        // use it directly — it's the most faithful representation.
        if let text = plainText, text.contains("\n\n") {
            return text
        }

        // 2. HTML (web browsers put structured HTML but often collapse plain text)
        if let htmlString = pasteboard.string(forType: htmlType),
           let converted = convertHTMLToFormattedText(htmlString),
           !converted.isEmpty {
            // Only use HTML result if it's at least as structured as plain text
            if converted.contains("\n\n") || plainText == nil || plainText?.isEmpty == true {
                return converted
            }
        }

        // 3. RTF (Word, Pages, Mail rich text)
        if let rtfData = pasteboard.data(forType: .rtf),
           let converted = convertRTFToFormattedText(rtfData),
           !converted.isEmpty {
            if converted.contains("\n\n") || plainText == nil || plainText?.isEmpty == true {
                return converted
            }
        }

        // 4. Fall back to plain text (even without blank lines)
        return plainText
    }

    /// Convert HTML string to formatted plain text preserving layout structure
    private func convertHTMLToFormattedText(_ html: String) -> String? {
        // NSAttributedString's HTML parser represents paragraph breaks as a single \n
        // in the output .string (the visual blank line is stored as paragraphSpacing
        // attribute, which we lose when converting to plain text). To preserve blank
        // lines between paragraphs, inject explicit <br><br> after each block-level
        // closing tag before parsing — these survive parsing as literal \n\n.
        let preprocessedHTML = injectParagraphBreaks(html)

        guard let data = preprocessedHTML.data(using: .utf8) else { return nil }

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        guard let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return nil
        }

        return cleanupAttributedStringText(attributedString)
    }

    /// Inject <br><br> after block-level closing tags to preserve paragraph boundaries
    /// through NSAttributedString's HTML parser, which otherwise collapses them to single \n.
    ///
    /// Note: List items (`<li>`, `<dt>`, `<dd>`) and table rows (`<tr>`) are NOT included
    /// — they should be separated by a single newline, not a blank line. Their enclosing
    /// containers (`<ul>`, `<ol>`, `<table>`) still get blank-line treatment.
    private func injectParagraphBreaks(_ html: String) -> String {
        let pattern = #"</(p|div|h[1-6]|blockquote|pre|article|section|header|footer|nav|aside|figure|figcaption|ul|ol|table)\s*>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return html
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.stringByReplacingMatches(
            in: html,
            options: [],
            range: range,
            withTemplate: "</$1><br><br>"
        )
    }

    /// Convert RTF data to formatted plain text preserving layout structure
    private func convertRTFToFormattedText(_ rtfData: Data) -> String? {
        // Use NSAttributedString to parse RTF
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf
        ]

        guard let attributedString = try? NSAttributedString(data: rtfData, options: options, documentAttributes: nil) else {
            return nil
        }

        // RTF: walk the attributed string and use paragraph style to detect paragraph breaks.
        return attributedStringToTextPreservingParagraphs(attributedString)
    }

    /// Walk an NSAttributedString and emit plain text with \n\n at paragraph boundaries
    /// (detected via paragraphSpacing / paragraphSpacingBefore in the paragraph style).
    /// Used for RTF where we can't preprocess the source.
    private func attributedStringToTextPreservingParagraphs(_ attrStr: NSAttributedString) -> String? {
        let nsStr = attrStr.string as NSString
        guard nsStr.length > 0 else { return nil }

        var output = ""
        var paragraphStart = 0

        while paragraphStart < nsStr.length {
            let paragraphRange = nsStr.paragraphRange(for: NSRange(location: paragraphStart, length: 0))
            let paragraphText = nsStr.substring(with: paragraphRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !paragraphText.isEmpty {
                if !output.isEmpty {
                    // Check paragraph style to decide: blank line or single newline
                    let style = attrStr.attribute(.paragraphStyle, at: paragraphRange.location, effectiveRange: nil) as? NSParagraphStyle
                    let hasSpacing = (style?.paragraphSpacing ?? 0) > 0 || (style?.paragraphSpacingBefore ?? 0) > 0
                    output += hasSpacing ? "\n\n" : "\n"
                }
                output += paragraphText
            }

            paragraphStart = NSMaxRange(paragraphRange)
        }

        // Apply the same whitespace normalization as cleanupAttributedStringText
        var result = output.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    /// Clean up attributed string text while preserving layout structure
    private func cleanupAttributedStringText(_ attributedString: NSAttributedString) -> String? {
        // Get the plain text from attributed string (preserves line breaks from structure)
        var result = attributedString.string

        // Replace multiple spaces/tabs with single space (applies within lines)
        result = result.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        // Trim leading/trailing whitespace from each line.
        // This converts whitespace-only lines (e.g. from <p>&nbsp;</p>) to empty lines.
        result = result.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
        // Collapse 3+ consecutive newlines to exactly 2 (one blank line between paragraphs).
        // Must run AFTER line trimming so that "whitespace-only lines" become true empties
        // and participate in the collapse.
        result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        // Trim overall leading/trailing whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result.isEmpty ? nil : result
    }

}
