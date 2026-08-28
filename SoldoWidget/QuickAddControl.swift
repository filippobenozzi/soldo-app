import AppIntents
import SwiftUI
import WidgetKit

/// Control Center / Lock Screen / Action button control that jumps straight to
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

/// Lives in the widget target, so it stays free of any SwiftData dependency:
/// it only opens the app on the right screen through the `soldo://` scheme.
@available(iOS 18.0, *)
struct OpenQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource { "Nuova spesa" }
    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "soldo://add")!))
    }
}
