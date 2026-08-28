import SwiftUI

enum SoldoTheme {
    static let accent = Color(hex: "27AE60")
    static let accentDeep = Color(hex: "105C3C")
    static let warning = Color(hex: "E67E22")
    static let danger = Color(hex: "C0392B")

    static let cornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
}

extension View {
    /// The rounded surface used for every card in the app.
    func soldoCard(padding: CGFloat = SoldoTheme.cardPadding) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SoldoTheme.cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

/// Small round icon badge used in lists for categories and accounts.
struct SymbolBadge: View {
    let symbolName: String
    let colorHex: String
    var size: CGFloat = 38

    var body: some View {
        let color = Color(hex: colorHex)
        return Image(systemName: symbolName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.15), in: Circle())
    }
}

/// Ring showing how much of the monthly budget is gone.
struct BudgetRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10

    private var tint: Color {
        switch progress {
        case ..<0.75: SoldoTheme.accent
        case ..<1.0: SoldoTheme.warning
        default: SoldoTheme.danger
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.001))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: progress)
        }
    }
}

enum Haptics {
    static func success() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func tap() {
        guard AppSettings.shared.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
