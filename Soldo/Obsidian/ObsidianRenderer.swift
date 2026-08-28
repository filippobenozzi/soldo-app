import Foundation

/// A value-type copy of an expense, safe to hand to the sync engine off the main actor.
struct ExpenseExportItem: Sendable, Identifiable, Equatable {
    var id: UUID
    var amount: Decimal
    var currencyCode: String
    var date: Date
    var merchant: String
    var note: String
    var categoryName: String?
    var accountName: String?
    /// False when the expense is already in sync and the mode writes incrementally.
    var needsWrite: Bool = true
    /// Vault-relative path this expense was last written to, for `notePerExpense`.
    var existingRelativePath: String?
}

/// An expense that no longer exists in Soldo and has to be cleaned out of the vault.
struct ExpenseDeletionItem: Sendable, Equatable {
    var expenseID: UUID
    var date: Date
    var relativePath: String?
}

/// Turns expenses into the Markdown and CSV text written into the vault.
enum ObsidianRenderer {

    // MARK: - Formatters

    static func dateFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = format
        return formatter
    }

    static func isoDay(_ date: Date) -> String {
        dateFormatter("yyyy-MM-dd").string(from: date)
    }

    static func timeOfDay(_ date: Date) -> String {
        dateFormatter("HH:mm").string(from: date)
    }

    // MARK: - Escaping

    static func markdownTableCell(_ text: String) -> String {
        text
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: "<br>")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func csvField(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    /// YAML scalars are quoted whenever they could otherwise be misread.
    static func yamlScalar(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "\"\"" }
        let needsQuotes = trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: ":#{}[],&*?|-<>=!%@`\"'\n")) != nil
            || trimmed.first == " "
            || trimmed.last == " "
        guard needsQuotes else { return trimmed }
        let escaped = trimmed
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: " ")
        return "\"\(escaped)\""
    }

    // MARK: - Block references

    /// Obsidian block id used to find, update and delete a line in a daily note.
    static func blockRef(for id: UUID) -> String {
        let compact = id.uuidString.lowercased().replacingOccurrences(of: "-", with: "")
        return "^soldo-\(compact.prefix(12))"
    }

    // MARK: - Templates

    /// Substitutes `{{placeholder}}` tokens in file-name templates.
    static func applyTemplate(_ template: String, item: ExpenseExportItem) -> String {
        let replacements: [String: String] = [
            "{{data}}": isoDay(item.date),
            "{{date}}": isoDay(item.date),
            "{{ora}}": timeOfDay(item.date).replacingOccurrences(of: ":", with: "."),
            "{{time}}": timeOfDay(item.date).replacingOccurrences(of: ":", with: "."),
            "{{importo}}": Money.machineString(item.amount),
            "{{amount}}": Money.machineString(item.amount),
            "{{valuta}}": item.currencyCode,
            "{{currency}}": item.currencyCode,
            "{{categoria}}": item.categoryName ?? "",
            "{{category}}": item.categoryName ?? "",
            "{{conto}}": item.accountName ?? "",
            "{{account}}": item.accountName ?? "",
            "{{esercente}}": item.merchant,
            "{{merchant}}": item.merchant,
            "{{nota}}": item.note,
            "{{note}}": item.note,
            "{{id}}": item.id.uuidString.lowercased(),
        ]

        var output = template
        for (token, value) in replacements {
            output = output.replacingOccurrences(of: token, with: value)
        }

        let collapsed = output
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let sanitized = ObsidianPath.sanitizeFileName(collapsed)
        return sanitized.isEmpty ? "Spesa \(isoDay(item.date))" : sanitized
    }

    // MARK: - Single note (Markdown table)

    static let tableHeader = """
    | Data | Ora | Importo | Valuta | Categoria | Conto | Esercente | Nota |
    | --- | --- | ---: | --- | --- | --- | --- | --- |
    """

    static func tableRow(for item: ExpenseExportItem) -> String {
        let cells = [
            isoDay(item.date),
            timeOfDay(item.date),
            Money.machineString(item.amount),
            item.currencyCode,
            item.categoryName ?? "",
            item.accountName ?? "",
            item.merchant,
            item.note,
        ].map(markdownTableCell)
        return "| " + cells.joined(separator: " | ") + " |"
    }

    static func singleNoteDocument(items: [ExpenseExportItem], generatedAt: Date = .now) -> String {
        let sorted = items.sorted { $0.date > $1.date }
        let total = sorted.reduce(Decimal.zero) { $0 + $1.amount }
        let currency = sorted.first?.currencyCode ?? Money.defaultCurrencyCode

        var lines: [String] = []
        lines.append("---")
        lines.append("tipo: registro-spese")
        lines.append("generato-da: Soldo")
        lines.append("aggiornato: \(dateFormatter("yyyy-MM-dd'T'HH:mm:ssZ").string(from: generatedAt))")
        lines.append("voci: \(sorted.count)")
        lines.append("totale: \(Money.machineString(total))")
        lines.append("valuta: \(currency)")
        lines.append("tags:")
        lines.append("  - soldo")
        lines.append("---")
        lines.append("")
        lines.append("# Spese")
        lines.append("")
        lines.append("> [!warning] File gestito da Soldo")
        lines.append("> Questo file viene riscritto a ogni sincronizzazione. Non modificarlo a mano.")
        lines.append("")
        lines.append(tableHeader)
        lines.append(contentsOf: sorted.map(tableRow))
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - CSV

    static let csvHeader = "id,data,ora,importo,valuta,categoria,conto,esercente,nota"

    static func csvRow(for item: ExpenseExportItem) -> String {
        [
            csvField(item.id.uuidString.lowercased()),
            csvField(isoDay(item.date)),
            csvField(timeOfDay(item.date)),
            csvField(Money.machineString(item.amount)),
            csvField(item.currencyCode),
            csvField(item.categoryName ?? ""),
            csvField(item.accountName ?? ""),
            csvField(item.merchant),
            csvField(item.note),
        ].joined(separator: ",")
    }

    static func csvDocument(items: [ExpenseExportItem]) -> String {
        let sorted = items.sorted { $0.date > $1.date }
        return ([csvHeader] + sorted.map(csvRow)).joined(separator: "\n") + "\n"
    }

    // MARK: - Note per expense

    static func noteDocument(for item: ExpenseExportItem, configuration: ObsidianConfiguration) -> String {
        var lines: [String] = []
        lines.append("---")
        lines.append("tipo: spesa")
        lines.append("id: \(item.id.uuidString.lowercased())")
        lines.append("data: \(isoDay(item.date))")
        lines.append("ora: \(yamlScalar(timeOfDay(item.date)))")
        lines.append("importo: \(Money.machineString(item.amount))")
        lines.append("valuta: \(item.currencyCode)")
        if let category = item.categoryName, !category.isEmpty {
            lines.append("categoria: \(yamlScalar(category))")
        }
        if let account = item.accountName, !account.isEmpty {
            lines.append("conto: \(yamlScalar(account))")
        }
        if !item.merchant.isEmpty {
            lines.append("esercente: \(yamlScalar(item.merchant))")
        }
        if !configuration.frontMatterTags.isEmpty {
            lines.append("tags:")
            for tag in configuration.frontMatterTags where !tag.isEmpty {
                lines.append("  - \(tag)")
            }
        }
        lines.append("---")

        guard configuration.includeNoteBody else {
            return lines.joined(separator: "\n") + "\n"
        }

        let title = item.merchant.isEmpty ? (item.categoryName ?? "Spesa") : item.merchant
        lines.append("")
        lines.append("# \(title) — \(Money.string(item.amount, currencyCode: item.currencyCode))")
        lines.append("")

        var facts: [String] = []
        facts.append("**Data:** \(isoDay(item.date)) \(timeOfDay(item.date))")
        if let category = item.categoryName, !category.isEmpty { facts.append("**Categoria:** \(category)") }
        if let account = item.accountName, !account.isEmpty { facts.append("**Conto:** \(account)") }
        lines.append(facts.joined(separator: " · "))

        if !item.note.isEmpty {
            lines.append("")
            lines.append(item.note)
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Daily note

    static func dailyNoteLine(for item: ExpenseExportItem) -> String {
        var parts: [String] = ["**\(Money.string(item.amount, currencyCode: item.currencyCode))**"]
        if !item.merchant.isEmpty { parts.append(item.merchant) }
        if let category = item.categoryName, !category.isEmpty { parts.append(category) }
        if let account = item.accountName, !account.isEmpty { parts.append(account) }

        var line = "- " + parts.joined(separator: " · ")
        if !item.note.isEmpty {
            line += " — " + item.note.replacingOccurrences(of: "\n", with: " ")
        }
        return line + " " + blockRef(for: item.id)
    }

    static func emptyDailyNote(for date: Date, configuration: ObsidianConfiguration) -> String {
        let title = dateFormatter(configuration.dailyNoteDateFormat).string(from: date)
        return "# \(title)\n\n\(configuration.dailyNoteHeading)\n\n"
    }
}
