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
          place: String? = nil, latitude: Double? = nil, longitude: Double? = nil,
          needsWrite: Bool = true, existing: String? = nil) -> ExpenseExportItem {
    ExpenseExportItem(id: id, amount: Decimal(string: amount)!, currencyCode: "EUR", date: date,
                      merchant: merchant, note: note, categoryName: category, accountName: account,
                      placeName: place, latitude: latitude, longitude: longitude,
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
check(ObsidianPath.normalize("/Schei/Spese/") == "Schei/Spese", "slashes trimmed")
check(ObsidianPath.normalize("../../etc") == "etc", "parent traversal stripped")
check(ObsidianPath.normalize("a/../b") == "a/b", "inner traversal stripped")
check(ObsidianPath.ensureExtension("Spese", "md") == "Spese.md", "extension added")
check(ObsidianPath.ensureExtension("Spese.md", "md") == "Spese.md", "extension not doubled")
check(!ObsidianPath.sanitizeFileName("a/b:c*d?e").contains("/"), "illegal chars removed")

// MARK: - Note per expense

section("mode: notePerExpense")
var config = ObsidianConfiguration()
config.mode = .notePerExpense
config.folderPath = "Schei/Spese"

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
                                               relativePath: outcome.syncedWithPath[idB] ?? "Schei/Spese/2026-08-28 Bar 3.00.md")],
    configuration: config, root: root, outcome: &outcome)
check(!exists("Schei/Spese/2026-08-28 Bar 3.00.md"), "deleted note removed from vault")

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
config.folderPath = "Schei"
outcome = ObsidianSyncOutcome()
try! ObsidianSyncEngine.rebuildSingleNote(
    items: [item("12.50", "Coop", "pane | latte"), item("3.00", "Bar", "caffè\ndoppio")],
    configuration: config, root: root, outcome: &outcome)
let table = read("Schei/Spese.md") ?? ""
check(table.contains("| Data | Ora | Importo | Valuta | Categoria | Conto | Esercente | Luogo | Nota |"), "table header written")
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
let rebuilt = read("Schei/Spese.md") ?? ""
check(rebuilt.components(separatedBy: "\n").filter { $0.hasPrefix("| 2026") }.count == 1, "rebuild drops removed rows")

section("mode: csv")
config.mode = .csv
outcome = ObsidianSyncOutcome()
try! ObsidianSyncEngine.rebuildCSV(
    items: [item("12.50", "Coop", "dice \"ciao\""), item("3.00", "Bar, angolo")],
    configuration: config, root: root, outcome: &outcome)
let csv = read("Schei/Spese.csv") ?? ""
check(csv.hasPrefix("id,data,ora,importo"), "csv header")
check(csv.contains("\"dice \"\"ciao\"\"\""), "quotes escaped")
check(csv.contains("\"Bar, angolo\""), "comma-bearing field quoted")
check(csv.components(separatedBy: "\n").filter { !$0.isEmpty }.count == 3, "header + two rows")
check(csv.hasPrefix("id,data,ora,importo,valuta,categoria,conto,esercente,luogo,latitudine,longitudine,nota"), "csv header carries the place columns")

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

// MARK: - Place export

section("place in the exported note")
let located = item("18.00", "Farmacia Comunale", "tachipirina",
                   place: "Farmacia Comunale 3", latitude: 44.49381, longitude: 11.34272)
let locatedNote = ObsidianRenderer.noteDocument(for: located, configuration: ObsidianConfiguration())
check(locatedNote.contains("luogo: Farmacia Comunale 3"), "place in front matter")
check(locatedNote.contains("location: [44.493810, 11.342720]"), "map-plugin location key")
check(locatedNote.contains("coordinate: \"44.49381, 11.34272\""), "human readable coordinate")
check(locatedNote.contains("maps.apple.com"), "maps link in the body")

let locatedRow = ObsidianRenderer.tableRow(for: located)
let headerLine = ObsidianRenderer.tableHeader.components(separatedBy: "\n")[0]
check(locatedRow.filter { $0 == "|" }.count == headerLine.filter { $0 == "|" }.count,
      "table row has as many columns as the header")
check(headerLine.components(separatedBy: "|").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count == 9,
      "header has nine columns")
check(locatedRow.contains("Farmacia Comunale 3"), "place in the table row")

let locatedCSV = ObsidianRenderer.csvRow(for: located)
check(locatedCSV.contains("\"44.493810\"") && locatedCSV.contains("\"11.342720\""), "coordinates in csv")

let noPlaceNote = ObsidianRenderer.noteDocument(for: item("1.00", "Bar"), configuration: ObsidianConfiguration())
check(!noPlaceNote.contains("location:"), "no location key when there is no place")

let dailyWithPlace = ObsidianRenderer.dailyNoteLine(for: located)
check(dailyWithPlace.contains("Farmacia Comunale") && dailyWithPlace.contains("Farmacia Comunale 3"),
      "daily line keeps merchant and place when they differ")
let dailySamePlace = ObsidianRenderer.dailyNoteLine(for: item("1.00", "Coop", place: "Coop"))
check(dailySamePlace.components(separatedBy: "Coop").count == 2, "daily line does not repeat an identical place")

// MARK: - Point of interest mapping

section("place category mapping")
check(PlaceCategoryTable.candidateCategoryNames(for: "MKPOICategoryRestaurant").first == "ristoranti", "restaurant maps to Ristoranti")
check(PlaceCategoryTable.candidateCategoryNames(for: "MKPOICategoryCafe").first == "ristoranti", "cafe maps to Ristoranti")
check(PlaceCategoryTable.candidateCategoryNames(for: "MKPOICategoryFoodMarket").first == "spesa", "food market maps to Spesa")
check(PlaceCategoryTable.candidateCategoryNames(for: "MKPOICategoryGasStation").first == "trasporti", "gas station maps to Trasporti")
check(PlaceCategoryTable.candidateCategoryNames(for: "MKPOICategoryPharmacy").first == "salute", "pharmacy maps to Salute")
check(PlaceCategoryTable.candidateCategoryNames(for: "MKPOICategoryStore").first == "shopping", "store maps to Shopping")
check(PlaceCategoryTable.candidateCategoryNames(for: "MKPOICategoryHotel").first == "viaggi", "hotel maps to Viaggi")
check(PlaceCategoryTable.candidateCategoryNames(for: "MKPOICategoryFireStation").isEmpty, "unmapped category yields nothing")
check(PlaceCategoryTable.candidateCategoryNames(for: nil).isEmpty, "nil identifier yields nothing")

// MARK: - Receipt parsing

section("receipt: italian supermarket")
let conad = """
CONAD CITY
VIA GIUSEPPE VERDI 12
40121 BOLOGNA BO
P.IVA 03932390374
DOCUMENTO COMMERCIALE
di vendita o prestazione
DESCRIZIONE IVA PREZZO(€)
PANE 4 1,80
LATTE INTERO 4 1,29
PASTA 4 0,99
TOTALE COMPLESSIVO 4,08
di cui IVA 0,16
Pagamento contante 4,08
Resto 0,00
28-08-2026 14:32
""".components(separatedBy: "\n")
let conadScan = ReceiptParser.parse(lines: conad)
check(conadScan.total == Decimal(string: "4.08"), "total from TOTALE COMPLESSIVO (got \(conadScan.total.map { "\($0)" } ?? "nil"))")
check(conadScan.merchant == "Conad City", "merchant (got \(conadScan.merchant ?? "nil"))")
check(conadScan.street == "Via Giuseppe Verdi 12", "street (got \(conadScan.street ?? "nil"))")
check(conadScan.locality == "Bologna BO", "locality keeps the province code (got \(conadScan.locality ?? "nil"))")
check(conadScan.vatNumber == "03932390374", "VAT number")
if let d = conadScan.date {
    let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day, .hour, .minute], from: d)
    check(c.year == 2026 && c.month == 8 && c.day == 28 && c.hour == 14 && c.minute == 32, "date and time")
} else { check(false, "date parsed") }

section("receipt: total printed on the next line")
let mario = """
RISTORANTE DA MARIO
Piazza Maggiore 3
40124 Bologna
Tel. 051 123456
Coperto 2,00
Primi 24,00
Bevande 8,00
TOTALE EURO
34,00
GRAZIE E ARRIVEDERCI
""".components(separatedBy: "\n")
let marioScan = ReceiptParser.parse(lines: mario)
check(marioScan.total == Decimal(string: "34.00"), "total taken from the following line (got \(marioScan.total.map { "\($0)" } ?? "nil"))")
check(marioScan.merchant == "Ristorante Da Mario", "merchant (got \(marioScan.merchant ?? "nil"))")

section("receipt: subtotal and discount must not win")
let farmacia = """
FARMACIA SAN PIETRO
VIA ROMA 5
00185 ROMA RM
SUBTOTALE 45,00
SCONTO 5,00
TOTALE 40,00
""".components(separatedBy: "\n")
let farmaciaScan = ReceiptParser.parse(lines: farmacia)
check(farmaciaScan.total == Decimal(string: "40.00"), "TOTALE beats SUBTOTALE (got \(farmaciaScan.total.map { "\($0)" } ?? "nil"))")

section("receipt: fuel, unit price must be ignored")
let q8 = """
Q8 EASY
STAZIONE DI SERVIZIO
VIALE EUROPA 100
20090 MILANO MI
GASOLIO LT 32,45
PREZZO/LT 1,729
IMPORTO 56,10
CARTA DI CREDITO 56,10
25/08/26 09:15
""".components(separatedBy: "\n")
let q8Scan = ReceiptParser.parse(lines: q8)
check(q8Scan.total == Decimal(string: "56.10"), "IMPORTO wins over the card line (got \(q8Scan.total.map { "\($0)" } ?? "nil"))")
check(q8Scan.merchant == "Q8 Easy", "merchant (got \(q8Scan.merchant ?? "nil"))")
check(ReceiptParser.amounts(in: "PREZZO/LT 1,729").isEmpty, "three-decimal unit price is not money")
check(ReceiptParser.amounts(in: "TOTALE 1.729,50") == [Decimal(string: "1729.50")!], "thousands separator understood")

section("receipt: english, no italian keywords")
let starbucks = """
STARBUCKS COFFEE
123 Main Street
Latte 4.50
Muffin 3.25
SUBTOTAL 7.75
TAX 0.62
TOTAL 8.37
""".components(separatedBy: "\n")
let starbucksScan = ReceiptParser.parse(lines: starbucks)
check(starbucksScan.total == Decimal(string: "8.37"), "TOTAL beats SUBTOTAL and TAX (got \(starbucksScan.total.map { "\($0)" } ?? "nil"))")
check(starbucksScan.merchant == "Starbucks Coffee", "merchant (got \(starbucksScan.merchant ?? "nil"))")

section("receipt: no keyword at all falls back to the largest amount")
let bar = """
BAR CENTRALE
Caffè 1,20
Cornetto 1,50
2,70
""".components(separatedBy: "\n")
let barScan = ReceiptParser.parse(lines: bar)
check(barScan.total == Decimal(string: "2.70"), "largest amount used as total (got \(barScan.total.map { "\($0)" } ?? "nil"))")
check(barScan.merchant == "Bar Centrale", "merchant (got \(barScan.merchant ?? "nil"))")

section("receipt: candidate amounts offered for review")
check(conadScan.candidateAmounts.contains(Decimal(string: "4.08")!), "the chosen total is among the candidates")
check(conadScan.candidateAmounts.contains(Decimal(string: "1.80")!), "line items are candidates too")
check(conadScan.candidateAmounts == conadScan.candidateAmounts.sorted(by: >), "candidates are largest first")
check(Set(conadScan.candidateAmounts).count == conadScan.candidateAmounts.count, "candidates are de-duplicated")
check(!conadScan.candidateAmounts.contains(0), "zero is not offered")
check(q8Scan.candidateAmounts.contains(Decimal(string: "1.729")!) == false, "unit price is not a candidate")

section("receipt: place query and empty scan")
check(conadScan.placeQuery?.contains("Conad City") == true, "place query starts with the merchant")
check(conadScan.placeQuery?.contains("Via Giuseppe Verdi 12") == true, "place query carries the street")
check(ReceiptParser.parse(lines: []).isEmpty, "empty input yields an empty scan")
check(ReceiptParser.parse(lines: ["", "   "]).isEmpty, "blank lines yield an empty scan")

section("receipt: date edge cases")
check(ReceiptParser.findDate(in: ["13/07/2026"]) != nil, "day greater than 12 parses")
if let us = ReceiptParser.findDate(in: ["07/13/2026"]) {
    let c = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: us)
    check(c.month == 7 && c.day == 13, "american order is swapped back")
} else { check(false, "american order parses") }
check(ReceiptParser.findDate(in: ["99/99/9999"]) == nil, "nonsense date rejected")
check(ReceiptParser.findDate(in: ["01/01/2099"]) == nil, "future date rejected")

section("receipt: OCR line assembly rules")
check(ReceiptParser.tidy("  CONAD   CITY  ") == "Conad City", "spacing collapsed and shouting fixed")
check(ReceiptParser.tidy("Da Mario SRL") == "Da Mario SRL", "mixed case left alone")
check(ReceiptParser.tidy("PIZZERIA DA GINO SRL") == "Pizzeria Da Gino SRL", "company suffix preserved")
check(ReceiptParser.tidyLocality("BOLOGNA BO") == "Bologna BO", "province code kept uppercase")
check(ReceiptParser.tidy("RISTORANTE DA MARIO") == "Ristorante Da Mario", "two-letter words in a name are not province codes")


print("\n" + (failures == 0 ? "ALL CHECKS PASSED" : "\(failures) CHECK(S) FAILED"))
try? FileManager.default.removeItem(at: root)
exit(failures == 0 ? 0 : 1)
