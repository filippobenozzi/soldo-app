import AppIntents
import SwiftUI
import WidgetKit

/// Control Centre / Lock Screen / Action button: records a preset amount with one
/// tap, without opening Schei.
///
/// The amount is part of the control's own configuration — long-press the control
/// to change it, or add several, one per amount you use often. A control cannot
/// prompt for a value, so a preset is what makes a single tap actually record
/// something instead of quietly failing.
@available(iOS 18.0, *)
struct QuickAddControl: ControlWidget {
    // Unchanged across the rename: the system tracks placed controls by kind.
    let kind = "SoldoQuickAddControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: kind, intent: QuickAddControlConfiguration.self) { configuration in
            ControlWidgetButton(
                action: ControlQuickAddIntent(amount: configuration.amount, merchant: configuration.merchant)
            ) {
                Label(
                    Money.string(Decimal(configuration.amount), currencyCode: AppSettings.shared.currencyCode),
                    systemImage: "eurosign.circle.fill"
                )
            }
        }
        .displayName("Spesa veloce")
        .description("Registra un importo prestabilito con un tocco, senza aprire l'app.")
    }
}

/// The other half of the pair, for when the expense needs a category, una nota o
/// la scansione di uno scontrino: this one does open the app on the insert screen.
@available(iOS 18.0, *)
struct OpenScheiControl: ControlWidget {
    // Unchanged across the rename: the system tracks placed controls by kind.
    let kind = "SoldoOpenAddControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenQuickAddIntent()) {
                Label("Nuova spesa", systemImage: "square.and.pencil")
            }
        }
        .displayName("Nuova spesa")
        .description("Apre Schei sulla schermata di inserimento.")
    }
}
