import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(SyncCoordinator.self) private var coordinator
    @Environment(ObsidianVaultLink.self) private var vault
    @Environment(\.modelContext) private var context

    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var editingExpense: Expense?

    private var monthExpenses: [Expense] {
        expenses.filter { SpendingPeriod.month.contains($0.date) }
    }

    private var monthTotal: Decimal { SpendingSummary.total(monthExpenses) }
    private var todayTotal: Decimal { SpendingSummary.total(expenses, in: .today) }
    private var weekTotal: Decimal { SpendingSummary.total(expenses, in: .week) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthCard
                    quickStats
                    SyncStatusBanner()
                    recentSection
                }
                .padding(.horizontal)
                .padding(.bottom, 90)
            }
            .background(SoldoTheme.groupedBackground)
            .navigationTitle("Soldo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        router.presentAddExpense()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                    .accessibilityLabel("Aggiungi spesa")
                }
            }
            .overlay(alignment: .bottom) { addButton }
            .sheet(item: $editingExpense) { expense in
                AddExpenseView(editing: expense)
            }
            .refreshable {
                await coordinator.sync(context: context)
            }
        }
    }

    // MARK: - Pieces

    private var monthCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Questo mese")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(Money.string(monthTotal, currencyCode: settings.currencyCode))
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Spacer()
                if let budget = settings.monthlyBudget, budget > 0 {
                    let progress = NSDecimalNumber(decimal: monthTotal).doubleValue
                        / NSDecimalNumber(decimal: budget).doubleValue
                    ZStack {
                        BudgetRing(progress: progress)
                        Text("\(Int((progress * 100).rounded()))%")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                    }
                    .frame(width: 62, height: 62)
                }
            }

            if let budget = settings.monthlyBudget, budget > 0 {
                let remaining = budget - monthTotal
                HStack {
                    Label(
                        remaining >= 0 ? "Restano \(Money.string(remaining, currencyCode: settings.currencyCode))"
                                       : "Sforato di \(Money.string(-remaining, currencyCode: settings.currencyCode))",
                        systemImage: remaining >= 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(remaining >= 0 ? SoldoTheme.ink : SoldoTheme.danger)
                    Spacer()
                    Text("su \(Money.string(budget, currencyCode: settings.currencyCode))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .soldoCard()
    }

    private var quickStats: some View {
        HStack(spacing: 12) {
            statTile(title: "Oggi", value: todayTotal, symbol: "sun.max.fill")
            statTile(title: "Settimana", value: weekTotal, symbol: "calendar")
            statTile(
                title: "Media/giorno",
                value: SpendingSummary.dailyAverageThisMonth(expenses),
                symbol: "chart.line.uptrend.xyaxis"
            )
        }
    }

    private func statTile(title: String, value: Decimal, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(Money.compactString(value, currencyCode: settings.currencyCode))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .soldoCard(padding: 12)
    }

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Ultime spese")
                    .font(.headline)
                Spacer()
                if !expenses.isEmpty {
                    Button("Vedi tutte") { router.selectedTab = .history }
                        .font(.subheadline)
                }
            }

            if expenses.isEmpty {
                EmptyStateView(
                    symbol: "eurosign.circle",
                    title: "Ancora nessuna spesa",
                    message: "Tocca + per registrare la prima. Ci vogliono due secondi."
                )
                .soldoCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(expenses.prefix(8).enumerated()), id: \.element.id) { index, expense in
                        Button {
                            editingExpense = expense
                        } label: {
                            ExpenseRow(expense: expense)
                        }
                        .buttonStyle(.plain)

                        if index < min(expenses.count, 8) - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .soldoCard(padding: 12)
            }
        }
    }

    private var addButton: some View {
        Button {
            Haptics.tap()
            router.presentAddExpense()
        } label: {
            Label("Aggiungi spesa", systemImage: "plus")
                .font(.headline)
                .foregroundStyle(SoldoTheme.card)
                .padding(.vertical, 14)
                .padding(.horizontal, 26)
                .background(SoldoTheme.ink, in: Capsule())
                .shadow(color: .black.opacity(0.22), radius: 12, y: 6)
        }
        .padding(.bottom, 12)
    }
}

struct ExpenseRow: View {
    let expense: Expense

    var body: some View {
        HStack(spacing: 12) {
            SymbolBadge(
                symbolName: expense.category?.symbolName ?? "eurosign.circle.fill",
                colorHex: expense.category?.colorHex ?? "596275"
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(expense.displayTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(expense.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                    if let account = expense.account?.name {
                        Text("·")
                        Text(account).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.formattedAmount)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                SyncStateDot(state: expense.syncState)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct SyncStateDot: View {
    let state: SyncState

    var body: some View {
        switch state {
        case .synced:
            Label("Sincronizzata", systemImage: "checkmark.circle.fill")
                .labelStyle(.iconOnly)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        case .pending:
            Label("In attesa", systemImage: "clock")
                .labelStyle(.iconOnly)
                .font(.caption2)
                .foregroundStyle(.secondary)
        case .failed:
            Label("Errore", systemImage: "exclamationmark.triangle.fill")
                .labelStyle(.iconOnly)
                .font(.caption2)
                .foregroundStyle(SoldoTheme.danger)
        case .off:
            EmptyView()
        }
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
