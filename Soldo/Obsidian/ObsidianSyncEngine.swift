import Foundation

struct ObsidianSyncOutcome: Sendable {
    /// Expenses written to a note of their own, mapped to its vault-relative path.
    var syncedWithPath: [UUID: String] = [:]
    /// Expenses covered by a shared file, which has no per-expense path.
    var syncedWithoutPath: Set<UUID> = []
    /// Expense id → human readable failure reason.
    var failed: [UUID: String] = [:]
    /// Deletions that were successfully applied to the vault.
    var deleted: Set<UUID> = []
    /// A failure that stopped the whole run (no vault, no access…).
    var fatalError: String?
    var filesTouched: [String] = []

    var allSynced: Set<UUID> { Set(syncedWithPath.keys).union(syncedWithoutPath) }
    var isSuccess: Bool { fatalError == nil && failed.isEmpty }
}

/// Writes expenses into the Obsidian vault.
///
/// All file access is serialised on a private queue: the vault may live in iCloud
/// Drive, where concurrent writes to the same note would race. That queue is also
/// why `@unchecked Sendable` is sound here — the only stored state is the vault
/// link, which reads and writes nothing but thread-safe `UserDefaults`.
final class ObsidianSyncEngine: @unchecked Sendable {
    static let shared = ObsidianSyncEngine()

    private let queue = DispatchQueue(label: "im.filippo.soldo.obsidian-sync", qos: .utility)
    private let vault: ObsidianVaultLink

    init(vault: ObsidianVaultLink = .shared) {
        self.vault = vault
    }

    // MARK: - Public API

    func sync(
        items: [ExpenseExportItem],
        deletions: [ExpenseDeletionItem],
        configuration: ObsidianConfiguration
    ) async -> ObsidianSyncOutcome {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: ObsidianSyncOutcome(fatalError: "Sync non disponibile"))
                    return
                }
                continuation.resume(returning: self.performSync(items: items, deletions: deletions, configuration: configuration))
            }
        }
    }

    /// Writes a full JSON backup next to the exported data.
    func writeBackup(data: Data, configuration: ObsidianConfiguration) async -> Result<String, Error> {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: .failure(ObsidianError.noVaultSelected))
                    return
                }
                do {
                    let relativePath = try self.vault.withVault { root -> String in
                        let folder = ObsidianPath.normalize(configuration.folderPath)
                        let directory = folder.isEmpty ? root : root.appending(path: folder)
                        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        let fileName = ObsidianPath.ensureExtension(configuration.backupFileName, "json")
                        let fileURL = directory.appending(path: fileName)
                        try Self.coordinatedWrite(data, to: fileURL)
                        return folder.isEmpty ? fileName : "\(folder)/\(fileName)"
                    }
                    continuation.resume(returning: .success(relativePath))
                } catch {
                    continuation.resume(returning: .failure(error))
                }
            }
        }
    }

    /// Reads the vault's top-level folder names, used by the folder picker in Settings.
    func listFolders() async -> [String] {
        await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self else { return continuation.resume(returning: []) }
                let folders = (try? self.vault.withVault { root -> [String] in
                    let contents = try FileManager.default.contentsOfDirectory(
                        at: root,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )
                    return contents
                        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                        .map(\.lastPathComponent)
                        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                }) ?? []
                continuation.resume(returning: folders)
            }
        }
    }

    // MARK: - Sync implementation

    private func performSync(
        items: [ExpenseExportItem],
        deletions: [ExpenseDeletionItem],
        configuration: ObsidianConfiguration
    ) -> ObsidianSyncOutcome {
        var outcome = ObsidianSyncOutcome()

        do {
            try vault.withVault { root in
                switch configuration.mode {
                case .singleNote:
                    try Self.rebuildSingleNote(items: items, configuration: configuration, root: root, outcome: &outcome)
                case .csv:
                    try Self.rebuildCSV(items: items, configuration: configuration, root: root, outcome: &outcome)
                case .notePerExpense:
                    Self.syncNotesPerExpense(items: items, deletions: deletions, configuration: configuration, root: root, outcome: &outcome)
                case .dailyNote:
                    Self.syncDailyNotes(items: items, deletions: deletions, configuration: configuration, root: root, outcome: &outcome)
                }
            }
        } catch {
            outcome.fatalError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        return outcome
    }

    // MARK: Whole-file modes

    static func rebuildSingleNote(
        items: [ExpenseExportItem],
        configuration: ObsidianConfiguration,
        root: URL,
        outcome: inout ObsidianSyncOutcome
    ) throws {
        let folder = ObsidianPath.normalize(configuration.folderPath)
        let directory = folder.isEmpty ? root : root.appending(path: folder)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileName = ObsidianPath.ensureExtension(configuration.singleNoteFileName, "md")
        let fileURL = directory.appending(path: fileName)
        let document = ObsidianRenderer.singleNoteDocument(items: items)

        try coordinatedWrite(Data(document.utf8), to: fileURL)

        let relativePath = folder.isEmpty ? fileName : "\(folder)/\(fileName)"
        outcome.filesTouched.append(relativePath)
        for item in items { outcome.syncedWithoutPath.insert(item.id) }
    }

    static func rebuildCSV(
        items: [ExpenseExportItem],
        configuration: ObsidianConfiguration,
        root: URL,
        outcome: inout ObsidianSyncOutcome
    ) throws {
        let folder = ObsidianPath.normalize(configuration.folderPath)
        let directory = folder.isEmpty ? root : root.appending(path: folder)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileName = ObsidianPath.ensureExtension(configuration.csvFileName, "csv")
        let fileURL = directory.appending(path: fileName)
        let document = ObsidianRenderer.csvDocument(items: items)

        try coordinatedWrite(Data(document.utf8), to: fileURL)

        let relativePath = folder.isEmpty ? fileName : "\(folder)/\(fileName)"
        outcome.filesTouched.append(relativePath)
        for item in items { outcome.syncedWithoutPath.insert(item.id) }
    }

    // MARK: One note per expense

    static func syncNotesPerExpense(
        items: [ExpenseExportItem],
        deletions: [ExpenseDeletionItem],
        configuration: ObsidianConfiguration,
        root: URL,
        outcome: inout ObsidianSyncOutcome
    ) {
        let folder = ObsidianPath.normalize(configuration.folderPath)
        let directory = folder.isEmpty ? root : root.appending(path: folder)

        for deletion in deletions {
            if let path = deletion.relativePath {
                try? coordinatedRemove(at: root.appending(path: path))
            }
            outcome.deleted.insert(deletion.expenseID)
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            outcome.fatalError = "Non riesco a creare la cartella «\(folder)»: \(error.localizedDescription)"
            return
        }

        for item in items where item.needsWrite {
            do {
                let baseName = ObsidianRenderer.applyTemplate(configuration.noteFileNameTemplate, item: item)
                let fileName = try uniqueNoteFileName(base: baseName, for: item, in: directory)
                let fileURL = directory.appending(path: fileName)
                let relativePath = folder.isEmpty ? fileName : "\(folder)/\(fileName)"

                // The note may have been renamed by an edit — drop the previous file.
                if let previous = item.existingRelativePath, previous != relativePath {
                    try? coordinatedRemove(at: root.appending(path: previous))
                }

                let document = ObsidianRenderer.noteDocument(for: item, configuration: configuration)
                try coordinatedWrite(Data(document.utf8), to: fileURL)

                outcome.syncedWithPath[item.id] = relativePath
                outcome.filesTouched.append(relativePath)
            } catch {
                outcome.failed[item.id] = error.localizedDescription
            }
        }
    }

    /// Finds a free file name, reusing the one that already belongs to this expense.
    static func uniqueNoteFileName(base: String, for item: ExpenseExportItem, in directory: URL) throws -> String {
        let idLine = "id: \(item.id.uuidString.lowercased())"

        for suffix in 0...50 {
            let candidate = suffix == 0 ? "\(base).md" : "\(base) \(suffix + 1).md"
            let candidateURL = directory.appending(path: candidate)

            guard FileManager.default.fileExists(atPath: candidateURL.path(percentEncoded: false)) else {
                return candidate
            }
            // Reuse the file when it is this expense's own note.
            if let existing = try? String(contentsOf: candidateURL, encoding: .utf8), existing.contains(idLine) {
                return candidate
            }
        }

        return "\(base) \(item.id.uuidString.prefix(6)).md"
    }

    // MARK: Daily notes

    static func syncDailyNotes(
        items: [ExpenseExportItem],
        deletions: [ExpenseDeletionItem],
        configuration: ObsidianConfiguration,
        root: URL,
        outcome: inout ObsidianSyncOutcome
    ) {
        let folder = ObsidianPath.normalize(configuration.dailyNoteFolder)
        let directory = folder.isEmpty ? root : root.appending(path: folder)
        let formatter = ObsidianRenderer.dateFormatter(configuration.dailyNoteDateFormat)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            outcome.fatalError = "Non riesco a creare la cartella «\(folder)»: \(error.localizedDescription)"
            return
        }

        for deletion in deletions {
            let fileURL = directory.appending(path: "\(formatter.string(from: deletion.date)).md")
            if var content = try? coordinatedRead(at: fileURL) {
                let marker = ObsidianRenderer.blockRef(for: deletion.expenseID)
                var lines = content.components(separatedBy: "\n")
                let before = lines.count
                lines.removeAll { $0.contains(marker) }
                if lines.count != before {
                    content = lines.joined(separator: "\n")
                    try? coordinatedWrite(Data(content.utf8), to: fileURL)
                }
            }
            outcome.deleted.insert(deletion.expenseID)
        }

        // Group by day so each daily note is opened and written once.
        let grouped = Dictionary(grouping: items.filter(\.needsWrite)) { formatter.string(from: $0.date) }

        for (day, dayItems) in grouped {
            let fileURL = directory.appending(path: "\(day).md")
            do {
                var content = (try? coordinatedRead(at: fileURL))
                    ?? ObsidianRenderer.emptyDailyNote(for: dayItems[0].date, configuration: configuration)

                for item in dayItems.sorted(by: { $0.date < $1.date }) {
                    content = upsert(
                        line: ObsidianRenderer.dailyNoteLine(for: item),
                        marker: ObsidianRenderer.blockRef(for: item.id),
                        heading: configuration.dailyNoteHeading,
                        in: content
                    )
                }

                try coordinatedWrite(Data(content.utf8), to: fileURL)

                let relativePath = folder.isEmpty ? "\(day).md" : "\(folder)/\(day).md"
                outcome.filesTouched.append(relativePath)
                for item in dayItems { outcome.syncedWithPath[item.id] = relativePath }
            } catch {
                for item in dayItems { outcome.failed[item.id] = error.localizedDescription }
            }
        }
    }

    /// Replaces the line carrying `marker`, or inserts it at the end of the
    /// `heading` section (creating that section when the note doesn't have one).
    static func upsert(line: String, marker: String, heading: String, in content: String) -> String {
        var lines = content.components(separatedBy: "\n")

        if let index = lines.firstIndex(where: { $0.contains(marker) }) {
            lines[index] = line
            return lines.joined(separator: "\n")
        }

        let trimmedHeading = heading.trimmingCharacters(in: .whitespaces)
        guard !trimmedHeading.isEmpty,
              let headingIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == trimmedHeading })
        else {
            var appended = lines
            if !(appended.last?.trimmingCharacters(in: .whitespaces).isEmpty ?? true) { appended.append("") }
            if !trimmedHeading.isEmpty {
                appended.append(trimmedHeading)
                appended.append("")
            }
            appended.append(line)
            appended.append("")
            return appended.joined(separator: "\n")
        }

        // Walk to the end of the section, then back over any trailing blank lines.
        var insertion = headingIndex + 1
        while insertion < lines.count, !lines[insertion].hasPrefix("#") {
            insertion += 1
        }
        while insertion > headingIndex + 1, lines[insertion - 1].trimmingCharacters(in: .whitespaces).isEmpty {
            insertion -= 1
        }

        lines.insert(line, at: insertion)
        return lines.joined(separator: "\n")
    }

    // MARK: - Coordinated file access

    /// `NSFileCoordinator` is what makes writes safe when the vault sits in iCloud
    /// Drive — it also triggers the download of files that are not local yet.
    static func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordinatorError: NSError?
        var writeError: Error?

        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { destination in
            do {
                try data.write(to: destination, options: .atomic)
            } catch {
                writeError = error
            }
        }

        if let coordinatorError {
            throw ObsidianError.writeFailed(url.lastPathComponent, underlying: coordinatorError.localizedDescription)
        }
        if let writeError {
            throw ObsidianError.writeFailed(url.lastPathComponent, underlying: writeError.localizedDescription)
        }
    }

    static func coordinatedRead(at url: URL) throws -> String {
        var coordinatorError: NSError?
        var readError: Error?
        var result: String?

        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { source in
            do {
                result = try String(contentsOf: source, encoding: .utf8)
            } catch {
                readError = error
            }
        }

        if let coordinatorError { throw coordinatorError }
        if let readError { throw readError }
        guard let result else { throw CocoaError(.fileReadUnknown) }
        return result
    }

    static func coordinatedRemove(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }

        var coordinatorError: NSError?
        var removeError: Error?

        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinatorError) { target in
            do {
                try FileManager.default.removeItem(at: target)
            } catch {
                removeError = error
            }
        }

        if let coordinatorError { throw coordinatorError }
        if let removeError { throw removeError }
    }
}
