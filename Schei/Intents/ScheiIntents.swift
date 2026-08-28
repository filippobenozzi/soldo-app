import AppIntents
import Foundation
import SwiftData

/// Logs an expense without opening the app — the action to wire to an Apple Pay
/// automation, the Back Tap or the Action button.
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Aggiungi spesa" }
    static var description: IntentDescription {
        IntentDescription(
            "Registra una spesa in Schei e la sincronizza con il vault Obsidian.",
            categoryName: "Spese"
        )
    }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Importo", requestValueDialog: "Quanto hai speso?")
    var amount: Double

    @Parameter(title: "Esercente")
    var merchant: String?

    @Parameter(title: "Categoria")
    var category: CategoryEntity?

    @Parameter(title: "Conto")
    var account: AccountEntity?

    @Parameter(title: "Nota")
    var note: String?

    @Parameter(title: "Data")
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Aggiungi una spesa di \(\.$amount) da \(\.$merchant)") {
            \.$category
            \.$account
            \.$note
            \.$date
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ScheiModelContainer.shared.mainContext
        ScheiModelContainer.seedIfNeeded(context)

        let decimalAmount = Decimal(amount)
        guard decimalAmount > 0 else {
            throw $amount.needsValueError("Quanto hai speso?")
        }

        let settings = AppSettings.shared

        var resolvedCategory: SpendingCategory?
        if let category {
            resolvedCategory = fetchCategory(id: category.id, context: context)
        } else if let defaultID = settings.defaultCategoryID {
            resolvedCategory = fetchCategory(id: defaultID, context: context)
        }

        var resolvedAccount: PaymentAccount?
        if let account {
            resolvedAccount = fetchAccount(id: account.id, context: context)
        } else if let defaultID = settings.defaultAccountID {
            resolvedAccount = fetchAccount(id: defaultID, context: context)
        }

        let expense = Expense(
            amount: decimalAmount,
            currencyCode: settings.currencyCode,
            date: date ?? .now,
            merchant: (merchant ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            note: (note ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            category: resolvedCategory,
            account: resolvedAccount
        )
        context.insert(expense)

        // Best effort: an intent run from an automation still gets a place when the
        // user has granted location access, but never blocks on it.
        if settings.detectLocation, LocationService.shared.isAuthorized {
            if let place = await LocationService.shared.currentPlace() {
                expense.apply(place: place)
                if expense.merchant.isEmpty { expense.merchant = place.name }
                if resolvedCategory == nil, settings.autoCategoryFromPlace {
                    let categories = (try? context.fetch(FetchDescriptor<SpendingCategory>())) ?? []
                    expense.category = PlaceCategoryMapper.match(place, in: categories)
                }
            }
        }

        try? context.save()

        await SyncCoordinator.shared.sync(context: context)
        SyncCoordinator.shared.refreshWidgetSnapshot(context: context)

        let formatted = Money.string(decimalAmount, currencyCode: settings.currencyCode)
        let where_ = expense.merchant.isEmpty ? "" : " da \(expense.merchant)"
        return .result(dialog: IntentDialog("Registrata una spesa di \(formatted)\(where_)."))
    }

    @MainActor
    private func fetchCategory(id: UUID, context: ModelContext) -> SpendingCategory? {
        let descriptor = FetchDescriptor<SpendingCategory>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }

    @MainActor
    private func fetchAccount(id: UUID, context: ModelContext) -> PaymentAccount? {
        let descriptor = FetchDescriptor<PaymentAccount>(predicate: #Predicate { $0.id == id })
        return try? context.fetch(descriptor).first
    }
}

/// Opens Schei on the add-expense screen, optionally prefilled.
struct OpenAddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource { "Apri nuova spesa" }
    static var description: IntentDescription {
        IntentDescription("Apre Schei sulla schermata di inserimento spesa.", categoryName: "Spese")
    }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Importo")
    var amount: Double?

    @Parameter(title: "Esercente")
    var merchant: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Apri una nuova spesa") {
            \.$amount
            \.$merchant
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        var draft = ExpenseDraft()
        if let amount, amount > 0 {
            draft.amountText = Money.machineString(Decimal(amount)).replacingOccurrences(of: ".", with: ",")
        }
        draft.merchant = merchant ?? ""

        // Both paths matter: the router covers a warm launch, the inbox covers a
        // cold one where the UI is not listening yet.
        QuickAddInbox.post(amountText: draft.amountText, merchant: draft.merchant)
        AppRouter.shared.presentAddExpense(draft: draft)
        return .result()
    }
}

/// Forces a vault sync.
struct SyncObsidianIntent: AppIntent {
    static var title: LocalizedStringResource { "Sincronizza con Obsidian" }
    static var description: IntentDescription {
        IntentDescription("Scrive nel vault tutte le spese ancora in attesa.", categoryName: "Obsidian")
    }
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ScheiModelContainer.shared.mainContext
        await SyncCoordinator.shared.sync(context: context)

        switch SyncCoordinator.shared.status {
        case .failure(let message):
            return .result(dialog: IntentDialog("Sincronizzazione non riuscita: \(message)"))
        default:
            return .result(dialog: IntentDialog("Vault aggiornato."))
        }
    }
}

/// Returns how much has been spent in a period.
struct SpendingTotalIntent: AppIntent {
    static var title: LocalizedStringResource { "Totale speso" }
    static var description: IntentDescription {
        IntentDescription("Restituisce il totale speso nel periodo scelto.", categoryName: "Spese")
    }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Periodo", default: .month)
    var period: PeriodAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Totale speso \(\.$period)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let context = ScheiModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let expenses = (try? context.fetch(descriptor)) ?? []

        let total = SpendingSummary.total(expenses, in: period.period)
        let currency = AppSettings.shared.currencyCode
        let formatted = Money.string(total, currencyCode: currency)

        return .result(
            value: NSDecimalNumber(decimal: total).doubleValue,
            dialog: IntentDialog("Hai speso \(formatted).")
        )
    }
}

/// Siri phrases and the entries shown in the Shortcuts app.
struct ScheiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickAddExpenseIntent(),
            phrases: [
                "Spesa veloce con \(.applicationName)",
                "Quick expense in \(.applicationName)",
            ],
            shortTitle: "Spesa veloce",
            systemImageName: "bolt.fill"
        )
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Aggiungi una spesa a \(.applicationName)",
                "Segna una spesa su \(.applicationName)",
                "Add an expense to \(.applicationName)",
            ],
            shortTitle: "Aggiungi spesa",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: OpenAddExpenseIntent(),
            phrases: [
                "Nuova spesa in \(.applicationName)",
                "New expense in \(.applicationName)",
            ],
            shortTitle: "Apri nuova spesa",
            systemImageName: "square.and.pencil"
        )
        AppShortcut(
            intent: SpendingTotalIntent(),
            phrases: [
                "Quanto ho speso con \(.applicationName)",
                "How much did I spend in \(.applicationName)",
            ],
            shortTitle: "Totale speso",
            systemImageName: "sum"
        )
        AppShortcut(
            intent: SyncObsidianIntent(),
            phrases: [
                "Sincronizza \(.applicationName)",
                "Sync \(.applicationName)",
            ],
            shortTitle: "Sincronizza",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}
