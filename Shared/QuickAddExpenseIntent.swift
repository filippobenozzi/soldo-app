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

/// Records an expense from Control Centre, the Lock Screen or the app icon,
/// **without opening the app**: iOS asks for the amount with its own prompt, the
/// expense is written, and a confirmation is spoken back.
///
/// It lives in `Shared/` so both the app and the widget extension declare it, and
/// the database sits in the App Group container so whichever process runs it can
/// write. Everything else — category, account, currency — comes from the defaults
/// the user already set.
struct QuickAddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Spesa veloce" }

    static var description: IntentDescription {
        IntentDescription(
            "Chiede solo l'importo e registra la spesa, senza aprire Soldo.",
            categoryName: "Spese"
        )
    }

    /// The whole point: no app launch.
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

        let context = SoldoModelContainer.shared.mainContext
        SoldoModelContainer.seedIfNeeded(context)

        let settings = AppSettings.shared
        let expense = Expense(
            amount: decimal,
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

        let formatted = Money.string(decimal, currencyCode: settings.currencyCode)
        return .result(dialog: IntentDialog("Registrata una spesa di \(formatted)."))
    }

    @MainActor
    private func defaultCategory(context: ModelContext) -> SpendingCategory? {
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
    private func defaultAccount(context: ModelContext) -> PaymentAccount? {
        guard let id = AppSettings.shared.defaultAccountID else { return nil }
        let accounts = (try? context.fetch(FetchDescriptor<PaymentAccount>())) ?? []
        return accounts.first { $0.id == id }
    }
}
