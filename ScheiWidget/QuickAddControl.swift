import AppIntents
import SwiftUI
import WidgetKit

/// Control Centre, Lock Screen and Action button: opens Schei straight on the
/// compact keypad sheet.
///
/// Earlier versions tried to record without coming forward at all. That cannot
/// work: a control has no way to ask for an amount, and an intent performed inside
/// the widget extension only reaches the shared database when the App Group is
/// actually granted — which sideloading does not guarantee. Opening the app on a
/// one-number sheet is the version that always works.
@available(iOS 18.0, *)
struct QuickAddControl: ControlWidget {
    // Unchanged across the rename: the system tracks placed controls by kind.
    let kind = "SoldoQuickAddControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenQuickAddIntent()) {
                Label("Spesa veloce", systemImage: "eurosign.circle.fill")
            }
        }
        .displayName("Spesa veloce")
        .description("Apre il tastierino di Schei per registrare una spesa.")
    }
}
