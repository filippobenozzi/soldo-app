import SwiftUI

/// The palette, sampled from SyncSpend's own screenshots: no accent colour at all,
/// just ink on paper. Everything that used to be green is now the label colour, so
/// the app inverts cleanly in dark mode.
enum SoldoTheme {
    /// Primary ink — black in light mode, white in dark mode.
    static let ink = Color.primary

    /// Page background behind the cards (#F5F5F5 in light mode).
    static let groupedBackground = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.0, alpha: 1)
            : UIColor(red: 0.961, green: 0.961, blue: 0.961, alpha: 1)
    })

    /// Card and row surfaces (#FFFFFF in light mode).
    static let card = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.110, alpha: 1)
            : UIColor(white: 1.0, alpha: 1)
    })

    /// The soft square behind a category icon (#EDEDED in light mode).
    static let badge = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.173, alpha: 1)
            : UIColor(red: 0.929, green: 0.929, blue: 0.929, alpha: 1)
    })

    /// A switch always draws a white knob, so tinting its track pure white makes
    /// the whole control vanish in dark mode. Switches get their own tone instead:
    /// black on paper, mid grey on black.
    static let switchTint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.58, alpha: 1)
            : UIColor(white: 0.0, alpha: 1)
    })

    /// Hairline separators inside cards.
    static let separator = Color(uiColor: .separator)

    /// Reserved for destructive actions and budget overruns — the one place where
    /// a monochrome design still needs a signal colour.
    static let danger = Color(uiColor: .systemRed)

    static let cornerRadius: CGFloat = 18
    static let badgeCornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16

    /// Category and account colours are stored per item, but the app renders them
    /// in ink unless the user turns colours on in Settings.
    static func tint(_ hex: String) -> Color {
        AppSettings.shared.useCategoryColors ? Color(hex: hex) : ink
    }

    /// Distinguishable greys for charts when colours are off, so a pie chart stays
    /// readable without introducing a palette.
    static func chartTint(_ hex: String, index: Int, count: Int) -> Color {
        guard !AppSettings.shared.useCategoryColors else { return Color(hex: hex) }
        guard count > 1 else { return ink }
        let step = Double(index) / Double(max(count - 1, 1))
        let white = 0.10 + step * 0.62
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1.0 - white * 0.85, alpha: 1)
                : UIColor(white: white, alpha: 1)
        })
    }
}

extension View {
    /// Applies the switch tone. Every `Toggle` in the app uses it.
    func soldoSwitch() -> some View {
        tint(SoldoTheme.switchTint)
    }

    /// The rounded white surface used for every card in the app.
    func soldoCard(padding: CGFloat = SoldoTheme.cardPadding) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: SoldoTheme.cornerRadius, style: .continuous)
                    .fill(SoldoTheme.card)
            )
    }
}

/// Rounded-square icon badge, matching the list rows in the reference design.
struct SymbolBadge: View {
    let symbolName: String
    let colorHex: String
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(SoldoTheme.tint(colorHex))
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .fill(AppSettings.shared.useCategoryColors
                          ? Color(hex: colorHex).opacity(0.15)
                          : SoldoTheme.badge)
            )
    }
}

/// Ring showing how much of the monthly budget is gone.
struct BudgetRing: View {
    let progress: Double
    var lineWidth: CGFloat = 9

    private var tint: Color {
        progress > 1 ? SoldoTheme.danger : SoldoTheme.ink
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(SoldoTheme.badge, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.001))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.snappy, value: progress)
        }
    }
}

/// Filled black (or white, in dark mode) button — the app's single strong accent.
struct InkButtonStyle: ButtonStyle {
    var expands = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(SoldoTheme.card)
            .frame(maxWidth: expands ? .infinity : nil)
            .padding(.vertical, 15)
            .padding(.horizontal, expands ? 0 : 24)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SoldoTheme.ink.opacity(configuration.isPressed ? 0.75 : 1))
            )
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
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
