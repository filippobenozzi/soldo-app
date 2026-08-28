import Foundation

/// Pulls merchant, total, date and address out of the lines OCR read from a receipt.
///
/// Kept free of Vision so it can be exercised by `Tools/run-checks.sh` against real
/// receipt text, without a camera or a simulator.
enum ReceiptParser {

    // MARK: - Regular expressions

    /// "12,50", "12.50", "1.234,56", "1,234.56"
    private static let amountPattern = try! NSRegularExpression(
        pattern: #"(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2}(?![\d])"#
    )
    private static let datePattern = try! NSRegularExpression(
        pattern: #"(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})"#
    )
    private static let timePattern = try! NSRegularExpression(
        pattern: #"(\d{1,2}):(\d{2})"#
    )
    private static let vatPattern = try! NSRegularExpression(
        pattern: #"(?:P\.?\s?IVA|PARTITA\s+IVA|VAT)\D{0,4}(\d{11})"#,
        options: [.caseInsensitive]
    )
    private static let postcodePattern = try! NSRegularExpression(
        pattern: #"\b(\d{5})\s+([A-Za-zÀ-ÿ'`\.\- ]{2,40})"#
    )

    /// Lines that can carry the amount actually due, best first.
    private static let totalKeywords: [(keyword: String, score: Int)] = [
        ("TOTALE COMPLESSIVO", 100),
        ("TOTALE DA PAGARE", 100),
        ("IMPORTO PAGATO", 95),
        ("TOTALE EURO", 92),
        ("TOTALE €", 92),
        ("GRAND TOTAL", 90),
        ("AMOUNT DUE", 90),
        ("TOTALE", 80),
        ("TOTAL", 78),
        ("IMPORTO", 70),
        ("PAGAMENTO ELETTRONICO", 55),
        ("CARTA DI CREDITO", 50),
        ("BANCOMAT", 50),
        ("CONTANTE", 48),
        ("CONTANTI", 48),
    ]

    /// Lines that look like a total but are not the amount due.
    private static let totalExclusions = [
        "SUBTOTALE", "SUB TOTALE", "SUBTOTAL", "IMPONIBILE", "IVA", "VAT", "TAX",
        "SCONTO", "DISCOUNT", "RESTO", "CHANGE", "NON RISCOSSO", "ARROTONDAMENTO",
        "TOTALE PEZZI", "TOTALE ARTICOLI", "N. PEZZI", "QUANTITA",
    ]

    /// Boilerplate that is never the shop's name.
    private static let merchantExclusions = [
        "DOCUMENTO COMMERCIALE", "SCONTRINO", "RICEVUTA", "P.IVA", "PARTITA IVA",
        "COD.FISC", "COD. FISC", "C.F.", "CODICE FISCALE", "TEL.", "TEL ", "WWW.",
        "HTTP", "@", "REG.", "CASSA", "OPERATORE", "SEDE", "FATTURA",
        "VIA ", "V.LE", "VIALE", "PIAZZA", "P.ZA", "P.ZZA", "CORSO", "C.SO",
        "LARGO", "VICOLO", "STRADA", "LOC.", "FRAZ.",
    ]

    private static let streetPrefixes = [
        "VIA", "V.LE", "VIALE", "PIAZZA", "P.ZA", "P.ZZA", "CORSO", "C.SO",
        "LARGO", "VICOLO", "STRADA", "LUNGOMARE", "CONTRADA",
    ]

    // MARK: - Entry point

    static func parse(lines rawLines: [String]) -> ReceiptScan {
        let lines = rawLines
            .map { $0.replacingOccurrences(of: "\u{00A0}", with: " ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var scan = ReceiptScan()
        scan.lines = lines
        scan.total = findTotal(in: lines)
        scan.candidateAmounts = Array(
            Set(lines.flatMap(amounts(in:)))
                .filter { $0 > 0 }
                .sorted(by: >)
                .prefix(14)
        ).sorted(by: >)
        scan.merchant = findMerchant(in: lines)
        scan.date = findDate(in: lines)
        scan.vatNumber = firstMatch(vatPattern, in: lines, group: 1)

        if let street = lines.first(where: { line in
            let upper = line.uppercased()
            return streetPrefixes.contains { upper.hasPrefix($0 + " ") || upper.hasPrefix($0 + ".") }
        }) {
            scan.street = tidy(street)
        }

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = postcodePattern.firstMatch(in: line, range: range),
               let cityRange = Range(match.range(at: 2), in: line) {
                let city = tidyLocality(String(line[cityRange]))
                if city.count >= 2 {
                    scan.locality = city
                    break
                }
            }
        }

        return scan
    }

    // MARK: - Total

    static func findTotal(in lines: [String]) -> Decimal? {
        var best: (score: Int, amount: Decimal)?

        for (index, line) in lines.enumerated() {
            let upper = line.uppercased()
            guard !totalExclusions.contains(where: { upper.contains($0) }) else { continue }

            guard let hit = totalKeywords.first(where: { upper.contains($0.keyword) }) else { continue }

            // The amount usually sits on the same line; some printers push it to the next.
            var amount = amounts(in: line).last
            if amount == nil, index + 1 < lines.count {
                let next = lines[index + 1].uppercased()
                if !totalExclusions.contains(where: { next.contains($0) }) {
                    amount = amounts(in: lines[index + 1]).last
                }
            }

            guard let amount, amount > 0 else { continue }
            if best == nil || hit.score > best!.score {
                best = (hit.score, amount)
            }
        }

        if let best { return best.amount }

        // No keyword matched — the largest amount on a receipt is almost always the total.
        let candidates = lines
            .filter { line in
                let upper = line.uppercased()
                return !totalExclusions.contains { upper.contains($0) }
            }
            .flatMap(amounts(in:))
        return candidates.max()
    }

    /// Every money-looking number on a line, in reading order.
    static func amounts(in line: String) -> [Decimal] {
        let range = NSRange(line.startIndex..., in: line)
        return amountPattern.matches(in: line, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: line) else { return nil }
            return Money.parse(String(line[matchRange]))
        }
    }

    // MARK: - Merchant

    static func findMerchant(in lines: [String]) -> String? {
        for line in lines.prefix(7) {
            let upper = line.uppercased()
            guard line.count >= 3 else { continue }
            guard !merchantExclusions.contains(where: { upper.contains($0) }) else { continue }

            // Skip anything that is mostly digits or punctuation: prices, codes, dates.
            let letters = line.filter { $0.isLetter }.count
            guard letters >= 3, Double(letters) / Double(line.count) > 0.5 else { continue }
            guard amounts(in: line).isEmpty else { continue }

            return tidy(line)
        }
        return nil
    }

    // MARK: - Date

    static func findDate(in lines: [String]) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let match = datePattern.firstMatch(in: line, range: range),
                  let dayRange = Range(match.range(at: 1), in: line),
                  let monthRange = Range(match.range(at: 2), in: line),
                  let yearRange = Range(match.range(at: 3), in: line),
                  var day = Int(line[dayRange]),
                  var month = Int(line[monthRange]),
                  var year = Int(line[yearRange])
            else { continue }

            if year < 100 { year += 2000 }
            // Receipts printed in an American format still show up occasionally.
            if day > 12, month > 12 { continue }
            if month > 12 { swap(&day, &month) }
            guard (1...31).contains(day), (1...12).contains(month), (2000...2100).contains(year) else { continue }

            var components = DateComponents(year: year, month: month, day: day, hour: 12)
            if let time = timePattern.firstMatch(in: line, range: range),
               let hourRange = Range(time.range(at: 1), in: line),
               let minuteRange = Range(time.range(at: 2), in: line),
               let hour = Int(line[hourRange]), let minute = Int(line[minuteRange]),
               (0...23).contains(hour), (0...59).contains(minute) {
                components.hour = hour
                components.minute = minute
            }

            if let date = calendar.date(from: components), date <= Date.now.addingTimeInterval(86_400) {
                return date
            }
        }
        return nil
    }

    // MARK: - Helpers

    private static func firstMatch(_ regex: NSRegularExpression, in lines: [String], group: Int) -> String? {
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range),
               let captured = Range(match.range(at: group), in: line) {
                return String(line[captured])
            }
        }
        return nil
    }

    /// Like `tidy`, but restores a trailing two-letter province code — "40121
    /// BOLOGNA BO" has to end up as "Bologna BO", not "Bologna Bo".
    static func tidyLocality(_ text: String) -> String {
        let tidied = tidy(text)
        var words = tidied.split(separator: " ").map(String.init)
        guard let last = words.last, last.count == 2, last.allSatisfy(\.isLetter) else { return tidied }
        words[words.count - 1] = last.uppercased()
        return words.joined(separator: " ")
    }

    /// Collapses spacing and un-shouts the ALL CAPS most receipt printers use.
    static func tidy(_ text: String) -> String {
        let collapsed = text
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: " *-_.,:;"))

        let letters = collapsed.filter { $0.isLetter }
        let isShouting = !letters.isEmpty && letters.allSatisfy { $0.isUppercase }
        guard isShouting else { return collapsed }

        return collapsed
            .split(separator: " ")
            .map { word -> String in
                // Keep short company suffixes as they are printed.
                let keep = ["SRL", "SPA", "SNC", "SAS", "SS", "S.R.L.", "S.P.A.", "DI", "E"]
                if keep.contains(String(word)) { return String(word) }
                return word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}
