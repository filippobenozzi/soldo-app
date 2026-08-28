import Foundation

var failures = 0
func check(_ condition: Bool, _ label: String) {
    if condition { print("  ok   \(label)") }
    else { print("  FAIL \(label)"); failures += 1 }
}
func section(_ title: String) { print("\n== \(title)") }

let root = URL(fileURLWithPath: NSTemporaryDirectory())
    .appending(path: "soldo-vault-\(UUID().uuidString.prefix(8))")
try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
print("vault: \(root.path)")

func read(_ relative: String) -> String? {
    try? String(contentsOf: root.appending(path: relative), encoding: .utf8)
}
func exists(_ relative: String) -> Bool {
    FileManager.default.fileExists(atPath: root.appending(path: relative).path)
}

let day = ISO8601DateFormatter().date(from: "2026-08-28T14:32:00Z")!
func item(_ amount: String, _ merchant: String, _ note: String = "", id: UUID = UUID(),
          date: Date = day, category: String? = "Spesa", account: String? = "Carta",
          needsWrite: Bool = true, existing: String? = nil) -> ExpenseExportItem {
    ExpenseExportItem(id: id, amount: Decimal(string: amount)!, currencyCode: "EUR", date: date,
                      merchant: merchant, note: note, categoryName: category, accountName: account,
                      needsWrite: needsWrite, existingRelativePath: existing)
}

// MARK: - Money parsing

section("Money.parse")
check(Money.parse("12,50") == Decimal(string: "12.50"), "italian comma decimals")
check(Money.parse("12.50") == Decimal(string: "12.50"), "dot decimals")
check(Money.parse("1.234,56") == Decimal(string: "1234.56"), "italian thousands + decimals")
check(Money.parse("1,234.56") == Decimal(string: "1234.56"), "english thousands + decimals")
check(Money.parse("€ 12,50") == Decimal(string: "12.50"), "leading currency symbol")
check(Money.parse("") == nil, "empty string rejected")
check(Money.parse("abc") == nil, "letters rejected")
check(Money.machineString(Decimal(string: "1234.5")!) == "1234.50", "machine string has no grouping")

// MARK: - Path safety

section("ObsidianPath")
check(ObsidianPath.normalize("/Soldo/Spese/") == "Soldo/Spese", "slashes trimmed")
check(ObsidianPath.normalize("../../etc") == "etc", "parent traversal stripped")
check(ObsidianPath.normalize("a/../b") == "a/b", "inner traversal stripped")
check(ObsidianPath.ensureExtension("Spese", "md") == "Spese.md", "extension added")
check(ObsidianPath.ensureExtension("Spese.md", "md") == "Spese.md", "extension not doubled")
check(!ObsidianPath.sanitizeFileName("a/b:c*d?e").contains("/"), "illegal chars removed")

// MARK: - Note per expense

section("mode: notePerExpense")
var config = ObsidianConfiguration()
config.mode = .notePerExpense
config.folderPath = "Soldo/Spese"

let idA = UUID(), idB = UUID(), idC = UUID()
var outcome = ObsidianSyncOutcome()
ObsidianSyncEngine.syncNotesPerExpense(
    items: [item("12.50", "Coop", "Pane e latte", id: idA),
            item("3.00", "Bar", id: idB),
            item("62.00", "Q8", id: idC)],
    deletions: [], configuration: config, root: root, outcome: &outcome)

check(outcome.fatalError == nil, "no fatal error")
check(outcome.failed.isEmpty, "no per-item failures")
check(outcome.syncedWithPath.count == 3, "three notes written")
let pathA = outcome.syncedWithPath[idA]!
check(exists(pathA), "note file exists at \(pathA)")
let noteA = read(pathA) ?? ""
check(noteA.hasPrefix("---\ntipo: spesa"), "front matter starts the file")
check(noteA.contains("id: \(idA.uuidString.lowercased())"), "front matter carries the id")
check(noteA.contains("importo: 12.50"), "amount is machine readable")
check(noteA.contains("valuta: EUR"), "currency present")
check(noteA.contains("categoria: Spesa"), "category present")
check(noteA.contains("- spesa"), "tag present")
check(noteA.contains("Pane e latte"), "note body present")

// Renaming the merchant must move the note, not leave a duplicate behind.
outcome = ObsidianSyncOutcome()
ObsidianSyncEngine.syncNotesPerExpense(
    items: [item("12.50", "Esselunga", "Pane e latte", id: idA, existing: pathA)],
    deletions: [], configuration: config, root: root, outcome: &outcome)
let renamedPath = outcome.syncedWithPath[idA]!
check(renamedPath != pathA, "renaming produces a new path")
check(!exists(pathA), "old note removed")
check(exists(renamedPath), "new note written")

// Deleting an expense must remove its note.
outcome = ObsidianSyncOutcome()
ObsidianSyncEngine.syncNotesPerExpense(
    items: [], deletions: [ExpenseDeletionItem(expenseID: idB, date: day,
                                               relativePath: outcome.syncedWithPath[idB] ?? "Soldo/Spese/2026-08-28 Bar 3.00.md")],
    configuration: config, root: root, outcome: &outcome)
check(!exists("Soldo/Spese/2026-08-28 Bar 3.00.md"), "deleted note removed from vault")

// Two different expenses that render to the same file name must not overwrite each other.
let idD = UUID(), idE = UUID()
outcome = ObsidianSyncOutcome()
ObsidianSyncEngine.syncNotesPerExpense(
    items: [item("5.00", "Edicola", id: idD), item("5.00", "Edicola", id: idE)],
    deletions: [], configuration: config, root: root, outcome: &outcome)
let pathD = outcome.syncedWithPath[idD]!, pathE = outcome.syncedWithPath[idE]!
check(pathD != pathE, "colliding names get distinct files (\(URL(fileURLWithPath: pathE).lastPathComponent))")
check(read(pathD)!.contains(idD.uuidString.lowercased()), "first file keeps its own id")
check(read(pathE)!.contains(idE.uuidString.lowercased()), "second file keeps its own id")

// Re-syncing the same expense must reuse its file rather than making a new one.
outcome = ObsidianSyncOutcome()
ObsidianSyncEngine.syncNotesPerExpense(
    items: [item("5.00", "Edicola", id: idD, existing: pathD)],
    deletions: [], configuration: config, root: root, outcome: &outcome)
check(outcome.syncedWithPath[idD] == pathD, "re-sync is idempotent on the path")

// MARK: - Daily note

section("mode: dailyNote")
config = ObsidianConfiguration()
config.mode = .dailyNote
config.dailyNoteFolder = "Diario"

let idF = UUID(), idG = UUID()
outcome = ObsidianSyncOutcome()
ObsidianSyncEngine.syncDailyNotes(
    items: [item("12.50", "Coop", id: idF), item("3.00", "Bar", id: idG)],
    deletions: [], configuration: config, root: root, outcome: &outcome)

let daily = read("Diario/2026-08-28.md") ?? ""
check(!daily.isEmpty, "daily note created")
check(daily.contains("## Spese"), "heading present")
check(daily.contains("Coop") && daily.contains("Bar"), "both expenses present")
check(daily.contains(ObsidianRenderer.blockRef(for: idF)), "block ref written")

// Editing must replace the line in place, never append a second one.
outcome = ObsidianSyncOutcome()
ObsidianSyncEngine.syncDailyNotes(
    items: [item("19.90", "Coop", id: idF)], deletions: [],
    configuration: config, root: root, outcome: &outcome)
let edited = read("Diario/2026-08-28.md") ?? ""
check(edited.components(separatedBy: ObsidianRenderer.blockRef(for: idF)).count == 2, "exactly one line for the edited expense")
check(edited.contains("19,90") || edited.contains("19.90"), "amount updated in place")
check(edited.contains("Bar"), "sibling line untouched")

// Deleting must drop just that line.
outcome = ObsidianSyncOutcome()
ObsidianSyncEngine.syncDailyNotes(
    items: [], deletions: [ExpenseDeletionItem(expenseID: idG, date: day, relativePath: nil)],
    configuration: config, root: root, outcome: &outcome)
let afterDelete = read("Diario/2026-08-28.md") ?? ""
check(!afterDelete.contains("Bar"), "deleted line removed")
check(afterDelete.contains("Coop"), "other line kept")

// A daily note the user already wrote must keep its own content.
let handWritten = "# 2026-08-29\n\nCose da fare oggi.\n\n## Spese\n\n## Note\n\nAltro testo.\n"
try! handWritten.write(to: root.appending(path: "Diario/2026-08-29.md"), atomically: true, encoding: .utf8)
let day2 = ISO8601DateFormatter().date(from: "2026-08-29T10:00:00Z")!
outcome = ObsidianSyncOutcome()
ObsidianSyncEngine.syncDailyNotes(
    items: [item("8.00", "Farmacia", id: UUID(), date: day2)], deletions: [],
    configuration: config, root: root, outcome: &outcome)
let merged = read("Diario/2026-08-29.md") ?? ""
check(merged.contains("Cose da fare oggi."), "existing content preserved")
check(merged.contains("Altro testo."), "content after the section preserved")
let speseIdx = merged.range(of: "## Spese")!.lowerBound
let noteIdx = merged.range(of: "## Note")!.lowerBound
let farmaciaIdx = merged.range(of: "Farmacia")!.lowerBound
check(farmaciaIdx > speseIdx && farmaciaIdx < noteIdx, "line inserted inside the Spese section")

// MARK: - Single note and CSV

section("mode: singleNote")
config = ObsidianConfiguration()
config.mode = .singleNote
config.folderPath = "Soldo"
outcome = ObsidianSyncOutcome()
try! ObsidianSyncEngine.rebuildSingleNote(
    items: [item("12.50", "Coop", "pane | latte"), item("3.00", "Bar", "caffè\ndoppio")],
    configuration: config, root: root, outcome: &outcome)
let table = read("Soldo/Spese.md") ?? ""
check(table.contains("| Data | Ora | Importo"), "table header written")
check(table.contains("| 2026-08-28 |"), "row written")
check(table.contains("pane \\| latte"), "pipe escaped inside a cell")
check(table.contains("caffè<br>doppio"), "newline escaped inside a cell")
check(table.contains("voci: 2"), "front matter counts entries")
check(table.contains("totale: 15.50"), "front matter totals the entries")
let rowCount = table.components(separatedBy: "\n").filter { $0.hasPrefix("| 2026") }.count
check(rowCount == 2, "exactly two data rows")

// A rebuild must reflect deletions, not accumulate rows.
outcome = ObsidianSyncOutcome()
try! ObsidianSyncEngine.rebuildSingleNote(
    items: [item("12.50", "Coop")], configuration: config, root: root, outcome: &outcome)
let rebuilt = read("Soldo/Spese.md") ?? ""
check(rebuilt.components(separatedBy: "\n").filter { $0.hasPrefix("| 2026") }.count == 1, "rebuild drops removed rows")

section("mode: csv")
config.mode = .csv
outcome = ObsidianSyncOutcome()
try! ObsidianSyncEngine.rebuildCSV(
    items: [item("12.50", "Coop", "dice \"ciao\""), item("3.00", "Bar, angolo")],
    configuration: config, root: root, outcome: &outcome)
let csv = read("Soldo/Spese.csv") ?? ""
check(csv.hasPrefix("id,data,ora,importo"), "csv header")
check(csv.contains("\"dice \"\"ciao\"\"\""), "quotes escaped")
check(csv.contains("\"Bar, angolo\""), "comma-bearing field quoted")
check(csv.components(separatedBy: "\n").filter { !$0.isEmpty }.count == 3, "header + two rows")

// MARK: - Vault root as destination

section("empty folder path writes to the vault root")
config = ObsidianConfiguration()
config.mode = .singleNote
config.folderPath = ""
outcome = ObsidianSyncOutcome()
try! ObsidianSyncEngine.rebuildSingleNote(items: [item("1.00", "Test")], configuration: config, root: root, outcome: &outcome)
check(exists("Spese.md"), "file written at the vault root")

// MARK: - YAML escaping

section("YAML escaping")
check(ObsidianRenderer.yamlScalar("Coop") == "Coop", "plain scalar unquoted")
check(ObsidianRenderer.yamlScalar("Bar: da Mario").hasPrefix("\""), "colon forces quoting")
check(ObsidianRenderer.yamlScalar("").contains("\"\""), "empty scalar quoted")
let tricky = ObsidianRenderer.noteDocument(
    for: item("1.00", "Da \"Gino\": il #1", "riga1\nriga2"), configuration: ObsidianConfiguration())
check(tricky.contains("esercente: \"Da \\\"Gino\\\": il #1\""), "quotes and hash escaped in front matter")

print("\n" + (failures == 0 ? "ALL CHECKS PASSED" : "\(failures) CHECK(S) FAILED"))
try? FileManager.default.removeItem(at: root)
exit(failures == 0 ? 0 : 1)
