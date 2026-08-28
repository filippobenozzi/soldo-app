import Foundation
import Observation

/// How expenses are laid down inside the vault.
enum ObsidianExportMode: String, Codable, CaseIterable, Identifiable {
    /// One Markdown table in a single note, rebuilt from the database on every sync.
    case singleNote
    /// One note per expense with YAML front matter — the Dataview-friendly layout.
    case notePerExpense
    /// A bullet appended to the daily note of the expense's day.
    case dailyNote
    /// A CSV file, rebuilt from the database on every sync.
    case csv

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleNote: "Nota unica"
        case .notePerExpense: "Una nota per spesa"
        case .dailyNote: "Nota giornaliera"
        case .csv: "File CSV"
        }
    }

    var subtitle: String {
        switch self {
        case .singleNote: "Tutte le spese in una tabella Markdown"
        case .notePerExpense: "Un file con front matter YAML, ideale per Dataview"
        case .dailyNote: "Una riga aggiunta al diario del giorno"
        case .csv: "Un CSV pronto per fogli di calcolo e Dataview"
        }
    }

    var symbolName: String {
        switch self {
        case .singleNote: "tablecells"
        case .notePerExpense: "doc.text"
        case .dailyNote: "calendar"
        case .csv: "tablecells.badge.ellipsis"
        }
    }

    /// Modes that regenerate their whole file on each sync, so edits and deletions
    /// in Schei are always reflected in the vault.
    var rebuildsWholeFile: Bool {
        switch self {
        case .singleNote, .csv: true
        case .notePerExpense, .dailyNote: false
        }
    }

    var managedFileWarning: String? {
        rebuildsWholeFile
            ? "Schei riscrive questo file a ogni sincronizzazione: le modifiche fatte a mano dentro Obsidian andranno perse."
            : nil
    }
}

/// Everything about *where* and *how* Schei writes into the vault.
/// Persisted as JSON in the shared defaults suite.
struct ObsidianConfiguration: Codable, Equatable {
    var mode: ObsidianExportMode = .notePerExpense

    /// Vault-relative folder for `singleNote`, `notePerExpense` and `csv`.
    var folderPath: String = "Schei"
    var singleNoteFileName: String = "Spese.md"
    var csvFileName: String = "Spese.csv"

    var dailyNoteFolder: String = "Diario"
    var dailyNoteDateFormat: String = "yyyy-MM-dd"
    var dailyNoteHeading: String = "## Spese"

    /// Placeholders: {{data}} {{ora}} {{importo}} {{valuta}} {{categoria}} {{conto}} {{esercente}} {{nota}} {{id}}
    var noteFileNameTemplate: String = "{{data}} {{esercente}} {{importo}}"
    var frontMatterTags: [String] = ["spesa"]
    var includeNoteBody: Bool = true

    var autoSync: Bool = true
    /// Also drop a full JSON backup next to the exported data.
    var writeBackupFile: Bool = false
    var backupFileName: String = "schei-backup.json"

    static let `default` = ObsidianConfiguration()

    /// Folder actually used by the current mode.
    var effectiveFolderPath: String {
        mode == .dailyNote ? dailyNoteFolder : folderPath
    }

    /// Human-readable preview of the destination, shown in Settings.
    var destinationDescription: String {
        let folder = ObsidianPath.normalize(effectiveFolderPath)
        let prefix = folder.isEmpty ? "" : folder + "/"
        switch mode {
        case .singleNote: return prefix + ObsidianPath.ensureExtension(singleNoteFileName, "md")
        case .csv: return prefix + ObsidianPath.ensureExtension(csvFileName, "csv")
        case .dailyNote: return prefix + "\(dailyNoteDateFormat).md"
        case .notePerExpense: return prefix + "\(noteFileNameTemplate).md"
        }
    }
}

/// Path helpers that keep everything inside the vault.
enum ObsidianPath {
    /// Trims slashes and whitespace and drops any component that would escape the vault.
    static func normalize(_ path: String) -> String {
        path
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
            .joined(separator: "/")
    }

    static func ensureExtension(_ name: String, _ ext: String) -> String {
        let trimmed = sanitizeFileName(name)
        guard !trimmed.isEmpty else { return "Schei.\(ext)" }
        return trimmed.lowercased().hasSuffix(".\(ext)") ? trimmed : "\(trimmed).\(ext)"
    }

    /// Strips characters that are illegal in file names or that confuse Obsidian links.
    static func sanitizeFileName(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|#^[]")
        let cleaned = name
            .components(separatedBy: illegal)
            .joined(separator: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(120))
    }
}

/// Observable wrapper so SwiftUI screens can bind directly to the configuration.
@Observable
final class ObsidianSettingsStore {
    static let shared = ObsidianSettingsStore()

    private let defaults: UserDefaults
    private let key = "obsidian.configuration"

    init(defaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ObsidianConfiguration.self, from: data) {
            self.configuration = decoded
        } else {
            self.configuration = .default
        }
    }

    var configuration: ObsidianConfiguration {
        didSet { persist() }
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: key)
    }
}
