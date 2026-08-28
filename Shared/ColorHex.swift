import SwiftUI

extension Color {
    /// Builds a colour from "#27AE60" or "27AE60"; falls back to grey on malformed input.
    init(hex: String) {
        let sanitized = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        guard sanitized.count == 6, Scanner(string: sanitized).scanHexInt64(&value) else {
            self = .gray
            return
        }

        self.init(
            .sRGB,
            red: Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8) / 255,
            blue: Double(value & 0x0000FF) / 255,
            opacity: 1
        )
    }
}

/// Ink-on-paper tinting, shared by the app and the widget extension.
///
/// Schei is monochrome by default; category colours are stored but only rendered
/// when the user turns them on, so both processes need the same rule.
enum InkPalette {
    static func tint(_ hex: String, colorful: Bool) -> Color {
        colorful ? Color(hex: hex) : .primary
    }
}

/// The palette offered when creating categories and accounts.
enum ScheiPalette {
    static let hexes = [
        "27AE60", "16A085", "2E86DE", "5F6CAF", "8E44AD", "C0392B",
        "E67E22", "F39C12", "D35400", "E84393", "0FB9B1", "596275",
    ]

    static func random() -> String {
        hexes.randomElement() ?? "27AE60"
    }
}
