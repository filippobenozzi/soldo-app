import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(SyncCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var context

    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query(sort: \SpendingCategory.sortIndex) private var categories: [SpendingCategory]

    @State private var searchText = ""
    @State private var period: SpendingPeriod = .month
    @State private var categoryFilterID: UUID?
    @State private var editingExpense: Expense?

    private var filtered: [Expense] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return expenses.filter { expense in
            guard period.contains(expense.date) else { return false }
            if let categoryFilterID, expense.category?.id != categoryFilterID { return false }
            guard !query.isEmpty else { return true }
            return expense.merchant.lowercased().contains(query)
                || expense.note.lowercased().contains(query)
                || (expense.category?.name.lowercased().contains(query) ?? false)
                || (expense.account?.name.lowercased().contains(query) ?? false)
        }
    }

    private var groupedByDay: [(day: Date, expenses: [Expense])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.date) }
        return groups
            .map { (day: $0.key, expenses: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    filterBar
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .listRowBackground(Color.clear)
                }

                if filtered.isEmpty {
                    Section {
                        EmptyStateView(
                            symbol: "magnifyingglass",
                            title: "Nessun risultato",
                            message: "Prova a cambiare periodo, categoria o testo cercato."
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        HStack {
                            Text("\(filtered.count) \(filtered.count == 1 ? "spesa" : "spese")")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Money.string(SpendingSummary.total(filtered), currencyCode: settings.currencyCode))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .font(.subheadline)
                    }

                    ForEach(groupedByDay, id: \.day) { group in
                        Section {
                            ForEach(group.expenses) { expense in
                                Button {
                                    editingExpense = expense
                                } label: {
                                    ExpenseRow(expense: expense)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        delete(expense)
                                    } label: {
                                        Label("Elimina", systemImage: "trash")
                                    }
                                }
                            }
                        } header: {
                            HStack {
                                Text(dayLabel(group.day))
                                Spacer()
                                Text(Money.string(SpendingSummary.total(group.expenses), currencyCode: settings.currencyCode))
                            }
                            .font(.caption)
                            .textCase(nil)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Storico")
            .searchable(text: $searchText, prompt: "Cerca esercente, nota, categoria")
            .sheet(item: $editingExpense) { AddExpenseView(editing: $0) }
            .refreshable { await coordinator.sync(context: context) }
        }
    }

    private var filterBar: some View {
        VStack(spacing: 10) {
            Picker("Periodo", selection: $period) {
                ForEach(SpendingPeriod.allCases) { period in
                    Text(period.shortLabel).tag(period)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "Tutte", hex: "596275", symbol: "square.grid.2x2", isSelected: categoryFilterID == nil) {
                        categoryFilterID = nil
                    }
                    ForEach(categories.filter { !$0.isArchived }) { category in
                        filterChip(
                            title: category.name,
                            hex: category.colorHex,
                            symbol: category.symbolName,
                            isSelected: categoryFilterID == category.id
                        ) {
                            categoryFilterID = categoryFilterID == category.id ? nil : category.id
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func filterChip(title: String, hex: String, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let color = Color(hex: hex)
        return Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.caption2)
                Text(title).font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func dayLabel(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Oggi" }
        if calendar.isDateInYesterday(day) { return "Ieri" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
    }

    private func delete(_ expense: Expense) {
        context.deleteExpense(expense)
        coordinator.dataDidChange(context: context)
        Haptics.warning()
    }
}
