import AppIntents

/// Opens Schei straight on the compact amount-first sheet.
///
/// This is what the Control Centre button runs. A control cannot show a keypad of
/// its own, and an intent that only writes data has no way to ask how much was
/// spent — so the app comes forward, but on a sheet that is one number and one tap,
/// not the full insert screen.
///
/// It lives in `Shared/`, so it is compiled into both the app and the widget
/// extension: `openAppWhenRun` makes iOS launch the app and perform the intent
/// there, which only works when the app declares the same intent.
struct OpenQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource { "Spesa veloce" }

    static var description: IntentDescription {
        IntentDescription("Apre Schei sul tastierino per registrare una spesa in due tocchi.", categoryName: "Spese")
    }

    static var openAppWhenRun: Bool { true }

    func perform() async throws -> some IntentResult {
        QuickAddInbox.post(mode: .quick)
        return .result()
    }
}
