import AppIntents

/// Opens Soldo straight on the add-expense screen.
///
/// This lives in `Shared/`, so it is compiled into both the app and the widget
/// extension. That matters: `openAppWhenRun` makes iOS launch the app and perform
/// the intent *there*, which only works when the app declares the same intent.
/// An earlier version returned `OpenURLIntent` from a widget-only intent, and
/// nothing happened — `OpenURLIntent` is a `SystemIntent`, not an `AppIntent`.
struct OpenQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource { "Nuova spesa" }

    static var description: IntentDescription {
        IntentDescription("Apre Soldo sulla schermata di inserimento spesa.", categoryName: "Spese")
    }

    static var openAppWhenRun: Bool { true }

    /// Hidden from the Shortcuts gallery: `OpenAddExpenseIntent` is the richer,
    /// parameterised action people should find there.
    static var isDiscoverable: Bool { false }

    func perform() async throws -> some IntentResult {
        QuickAddInbox.post()
        return .result()
    }
}
