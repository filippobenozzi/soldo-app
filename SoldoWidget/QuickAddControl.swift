import AppIntents
import SwiftUI
import WidgetKit

/// Control Centre / Lock Screen / Action button: asks for the amount with the
/// system prompt and records the expense **without opening Soldo**.
@available(iOS 18.0, *)
struct QuickAddControl: ControlWidget {
    let kind = "SoldoQuickAddControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: QuickAddExpenseIntent()) {
                Label("Spesa veloce", systemImage: "eurosign.circle.fill")
            }
        }
        .displayName("Spesa veloce")
        .description("Chiede l'importo e registra la spesa, senza aprire l'app.")
    }
}

/// The other half of the pair, for when the expense needs a category, una nota or
/// a receipt scan: this one does open the app on the insert screen.
@available(iOS 18.0, *)
struct OpenSoldoControl: ControlWidget {
    let kind = "SoldoOpenAddControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenQuickAddIntent()) {
                Label("Nuova spesa", systemImage: "square.and.pencil")
            }
        }
        .displayName("Nuova spesa")
        .description("Apre Soldo sulla schermata di inserimento.")
    }
}
