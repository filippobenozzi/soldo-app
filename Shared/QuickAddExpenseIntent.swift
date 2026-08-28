import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Lets the app run work that only it can do after an expense is saved somewhere
/// else — syncing the vault, rebuilding the widget snapshot. The app installs the
/// hook at launch; in the widget extension it simply stays `nil`.
enum QuickAddHooks {
    @MainActor static var didSaveExpense: ((Expense) async -> Void)?
}

/// The bit both quick-add paths share: write the expense using whatever defaults
/// the user already set, then let the app finish the job if it is the one running.
enum QuickExpenseWriter {
    @MainActor
    @discardableResult
    static func record(amount: Decimal, merchant: String?) async -> Expense {
        let context = ScheiModelContainer.shared.mainContext
        ScheiModelContainer.seedIfNeeded(context)

        let settings = AppSettings.shared
        let expense = Expense(
            amount: amount,
            currencyCode: settings.currencyCode,
            date: .now,
            merchant: (merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            category: defaultCategory(context: context),
            account: defaultAccount(context: context)
        )
        context.insert(expense)
        try? context.save()

        if let hook = QuickAddHooks.didSaveExpense {
            // Running inside the app: sync the vault and refresh the widget now.
            await hook(expense)
        } else {
            // Running inside the extension: the expense is safely stored and will
            // reach Obsidian the next time the app runs.
            WidgetCenter.shared.reloadAllTimelines()
        }
        return expense
    }

    @MainActor
    private static func defaultCategory(context: ModelContext) -> SpendingCategory? {
        let categories = (try? context.fetch(
            FetchDescriptor<SpendingCategory>(sortBy: [SortDescriptor(\.sortIndex)])
        )) ?? []
        if let id = AppSettings.shared.defaultCategoryID,
           let match = categories.first(where: { $0.id == id }) {
            return match
        }
        return categories.first { !$0.isArchived }
    }

    @MainActor
    private static func defaultAccount(context: ModelContext) -> PaymentAccount? {
        guard let id = AppSettings.shared.defaultAccountID else { return nil }
        let accounts = (try? context.fetch(FetchDescriptor<PaymentAccount>())) ?? []
        return accounts.first { $0.id == id }
    }
}

/// Records an expense **without opening the app**, asking for the amount first.
///
/// The prompt is the system's own, which is why this is the action to put in a
/// Shortcut: run it from the Lock Screen and iOS asks "Quanto hai speso?" before
/// saving. Control Centre buttons cannot prompt, which is what
/// `ControlQuickAddIntent` is for.
struct QuickAddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Spesa veloce" }

    static var description: IntentDescription {
        IntentDescription(
            "Chiede solo l'importo e registra la spesa, senza aprire Schei.",
            categoryName: "Spese"
        )
    }

    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Importo", requestValueDialog: IntentDialog("Quanto hai speso?"))
    var amount: Double

    @Parameter(title: "Esercente")
    var merchant: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Spesa veloce di \(\.$amount)") {
            \.$merchant
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let decimal = Decimal(amount)
        guard decimal > 0 else {
            throw $amount.needsValueError("Quanto hai speso?")
        }

        await QuickExpenseWriter.record(amount: decimal, merchant: merchant)
        let formatted = Money.string(decimal, currencyCode: AppSettings.shared.currencyCode)
        return .result(dialog: IntentDialog("Registrata una spesa di \(formatted)."))
    }
}

/// What a Control Centre button runs.
///
/// A control cannot ask the user anything: it fires the intent and that is that.
/// So the amount is fixed when the control is added — see
/// `QuickAddControlConfiguration` — and the intent always has a value to work
/// with. The earlier version relied on a prompt that never appeared, which is why
/// tapping the button did nothing at all.
struct ControlQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource { "Registra spesa preimpostata" }
    static var openAppWhenRun: Bool { false }
    static var isDiscoverable: Bool { false }

    @Parameter(title: "Importo", default: 5.0)
    var amount: Double

    @Parameter(title: "Esercente")
    var merchant: String?

    init() {}

    init(amount: Double, merchant: String?) {
        self.amount = amount
        self.merchant = merchant
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let decimal = Decimal(amount)
        guard decimal > 0 else {
            return .result(dialog: IntentDialog("Imposta un importo per questo controllo."))
        }

        await QuickExpenseWriter.record(amount: decimal, merchant: merchant)
        let formatted = Money.string(decimal, currencyCode: AppSettings.shared.currencyCode)
        return .result(dialog: IntentDialog("Registrata una spesa di \(formatted)."))
    }
}

/// The control's own settings, edited by long-pressing it in Control Centre.
/// Add one control per amount you use often — un caffè, un pranzo, un pieno.
struct QuickAddControlConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource { "Spesa veloce" }

    static var description: IntentDescription {
        IntentDescription("Scegli l'importo che questo pulsante registra.", categoryName: "Spese")
    }

    @Parameter(title: "Importo", default: 5.0)
    var amount: Double

    @Parameter(title: "Esercente")
    var merchant: String?

    /// A configuration intent only carries the control's settings and is never
    /// actually run. AppIntents ships a default `perform()` for exactly this, but
    /// it is not marked available in app extensions — where the control lives — so
    /// it has to be spelled out.
    func perform() async throws -> Never {
        throw ConfigurationIntentNotPerformable()
    }
}

private struct ConfigurationIntentNotPerformable: Error {}
