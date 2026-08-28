import AppIntents
import SwiftUI
import WidgetKit

/// Control Centre, Lock Screen and Action button control that jumps straight to
/// the add-expense screen.
@available(iOS 18.0, *)
struct QuickAddControl: ControlWidget {
    let kind = "SoldoQuickAddControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenQuickAddIntent()) {
                Label("Nuova spesa", systemImage: "eurosign.circle.fill")
            }
        }
        .displayName("Nuova spesa")
        .description("Apre Soldo per registrare una spesa.")
    }
}
