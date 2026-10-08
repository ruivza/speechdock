import Foundation

/// A single transcription history entry
struct TranscriptionHistoryEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let provider: String
    let text: String
    let wordCount: Int

    /// Short preview text for menu display (first 40 characters)
    var preview: String {
        let cleaned = text.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= 40 {
            return cleaned
        }
        return String(cleaned.prefix(40)) + "..."
    }

    /// Shared formatter for `formattedDate` (DateFormatter creation is expensive)
    private static let sharedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    /// Formatted date string for display
    var formattedDate: String {
        Self.sharedDateFormatter.string(from: date)
    }
}

/// Manages transcription history persistence using JSON file in Application Support
@MainActor
final class TranscriptionHistoryService {
    static let shared = TranscriptionHistoryService()
    static let enabledPreference = "saveTranscriptionHistory"

    private let maxEntries = 50
    private let fileName = "transcription_history.json"
    private var entries: [TranscriptionHistoryEntry] = []
    private let defaults: UserDefaults
    private let directoryURL: URL?

    init(defaults: UserDefaults = .standard, directoryURL: URL? = nil) {
        self.defaults = defaults
        self.directoryURL = directoryURL
        loadHistory()
    }

    var isEnabled: Bool {
        get { defaults.object(forKey: Self.enabledPreference) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Self.enabledPreference)
            entries.removeAll()
            if newValue { loadHistory() }
        }
    }

    /// Get all history entries (newest first)
    var allEntries: [TranscriptionHistoryEntry] {
        isEnabled ? entries : []
    }

    /// Add a new transcription to history
    func addEntry(text: String, provider: String) {
        guard isEnabled else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let wordCount = trimmed.split(omittingEmptySubsequences: true) { $0.isWhitespace || $0.isNewline }.count

        let entry = TranscriptionHistoryEntry(
            id: UUID(),
            date: Date(),
            provider: provider,
            text: trimmed,
            wordCount: wordCount
        )

        entries.insert(entry, at: 0)

        // Enforce max entries (FIFO)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveHistory()
    }

    /// Clear all history
    func clearHistory() {
        entries.removeAll()
        guard let url = historyFileURL, FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            dprint("TranscriptionHistoryService: Failed to clear history: \(error)")
        }
    }

    // MARK: - Persistence

    private var historyFileURL: URL? {
        guard let appDir = directoryURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("SpeechDock", isDirectory: true) else {
            return nil
        }

        return appDir.appendingPathComponent(fileName)
    }

    private func secureDirectory(for url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    }

    private func loadHistory() {
        guard isEnabled, let url = historyFileURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            try secureDirectory(for: url)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            let data = try Data(contentsOf: url)
            entries = Array(try JSONDecoder().decode([TranscriptionHistoryEntry].self, from: data).prefix(maxEntries))
            dprint("TranscriptionHistoryService: Loaded \(entries.count) entries")

        } catch {
            dprint("TranscriptionHistoryService: Failed to load history: \(error)")

        }
    }

    private func saveHistory() {
        guard isEnabled, let url = historyFileURL else { return }

        do {
            try secureDirectory(for: url)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            dprint("TranscriptionHistoryService: Failed to save history: \(error)")

        }
    }
}
