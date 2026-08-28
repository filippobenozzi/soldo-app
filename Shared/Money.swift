import Foundation

/// Currency parsing and formatting shared by the app, the widget and the Obsidian exporter.
enum Money {
    static let defaultCurrencyCode = "EUR"

    static func formatter(currencyCode: String, locale: Locale = .current) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode
        return formatter
    }

    /// "12,50 €"
    static func string(_ amount: Decimal, currencyCode: String, locale: Locale = .current) -> String {
        let formatter = formatter(currencyCode: currencyCode, locale: locale)
        return formatter.string(from: amount as NSDecimalNumber)
            ?? "\(amount) \(currencyCode)"
    }

    /// "1,2 k €" for tight layouts such as the small widget.
    static func compactString(_ amount: Decimal, currencyCode: String, locale: Locale = .current) -> String {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        guard abs(value) >= 10_000 else {
            return string(amount, currencyCode: currencyCode, locale: locale)
        }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        let thousands = NSNumber(value: value / 1000)
        let number = formatter.string(from: thousands) ?? "\(thousands)"
        return "\(number)k\u{00A0}\(symbol(for: currencyCode, locale: locale))"
    }

    static func symbol(for currencyCode: String, locale: Locale = .current) -> String {
        formatter(currencyCode: currencyCode, locale: locale).currencySymbol ?? currencyCode
    }

    /// Plain decimal string with no grouping, used for YAML front matter and CSV
    /// so the value stays machine readable inside Obsidian (Dataview, dataviewjs).
    static func machineString(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    /// Accepts what a person actually types: "12,50", "12.50", "1.234,56", "€ 12,50".
    static func parse(_ input: String, locale: Locale = .current) -> Decimal? {
        let cleaned = input
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { $0.isNumber || $0 == "," || $0 == "." || $0 == "-" }

        guard !cleaned.isEmpty else { return nil }

        let hasComma = cleaned.contains(",")
        let hasDot = cleaned.contains(".")

        var normalized = cleaned
        if hasComma, hasDot {
            // Whichever separator comes last is the decimal one.
            if cleaned.lastIndex(of: ",")! > cleaned.lastIndex(of: ".")! {
                normalized = cleaned.replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            } else {
                normalized = cleaned.replacingOccurrences(of: ",", with: "")
            }
        } else if hasComma {
            normalized = cleaned.replacingOccurrences(of: ",", with: ".")
        }

        return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Currencies offered in Settings, most likely first for an Italian user.
    static let commonCurrencyCodes = [
        "EUR", "USD", "GBP", "CHF", "SEK", "NOK", "DKK", "PLN", "CZK",
        "CAD", "AUD", "JPY", "CNY", "INR", "BRL", "TRY", "MXN", "ZAR",
    ]

    static func currencyDisplayName(_ code: String, locale: Locale = .current) -> String {
        let name = locale.localizedString(forCurrencyCode: code) ?? code
        return "\(code) — \(name.capitalized)"
    }
}
