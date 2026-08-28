import SwiftData
import SwiftUI

/// The fast-logging screen: a big amount, a numeric keypad and one tap per field.
struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(SyncCoordinator.self) private var coordinator

    @Query(sort: \SpendingCategory.sortIndex) private var allCategories: [SpendingCategory]
    @Query(sort: \PaymentAccount.sortIndex) private var allAccounts: [PaymentAccount]

    private let editingExpense: Expense?
    private let initialDraft: ExpenseDraft?

    @State private var amountText = ""
    @State private var merchant = ""
    @State private var note = ""
    @State private var date = Date.now
    @State private var selectedCategoryID: UUID?
    @State private var selectedAccountID: UUID?
    @State private var didLoadInitialState = false
    @State private var isConfirmingDelete = false
    @State private var isShowingDatePicker = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case merchant, note }

    init(draft: ExpenseDraft? = nil) {
        self.editingExpense = nil
        self.initialDraft = draft
    }

    init(editing expense: Expense) {
        self.editingExpense = expense
        self.initialDraft = nil
    }

    private var categories: [SpendingCategory] { allCategories.filter { !$0.isArchived } }
    private var accounts: [PaymentAccount] { allAccounts.filter { !$0.isArchived } }

    private var parsedAmount: Decimal? {
        guard let value = Money.parse(amountText), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 18) {
                        amountDisplay
                        categoryPicker
                        detailsCard
                        if editingExpense != nil { deleteButton }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
                .scrollDismissesKeyboard(.interactively)

                if focusedField == nil {
                    Keypad(
                        onDigit: appendDigit,
                        onSeparator: appendSeparator,
                        onDelete: deleteLast,
                        onLongDelete: { amountText = "" }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                saveButton
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(editingExpense == nil ? "Nuova spesa" : "Modifica spesa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
            }
            .animation(.snappy(duration: 0.22), value: focusedField)
        }
        .presentationDragIndicator(.visible)
        .onAppear(perform: loadInitialStateIfNeeded)
        .confirmationDialog("Eliminare questa spesa?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Elimina", role: .destructive, action: deleteExpense)
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Verrà rimossa anche dal vault Obsidian alla prossima sincronizzazione.")
        }
    }

    // MARK: - Sections

    private var amountDisplay: some View {
        VStack(spacing: 6) {
            Text(displayAmount)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.snappy, value: amountText)
                .foregroundStyle(parsedAmount == nil ? Color.secondary : Color.primary)

            Button {
                isShowingDatePicker.toggle()
            } label: {
                Label(dateLabel, systemImage: "calendar")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            if isShowingDatePicker {
                DatePicker("Data e ora", selection: $date)
                    .datePickerStyle(.graphical)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .soldoCard()
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Categoria")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories) { category in
                        chip(
                            title: category.name,
                            symbol: category.symbolName,
                            hex: category.colorHex,
                            isSelected: selectedCategoryID == category.id
                        ) {
                            Haptics.tap()
                            selectedCategoryID = selectedCategoryID == category.id ? nil : category.id
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "storefront")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                TextField("Esercente", text: $merchant)
                    .focused($focusedField, equals: .merchant)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .note }
            }
            .padding(.vertical, 12)

            Divider()

            HStack(spacing: 12) {
                Image(systemName: "text.alignleft")
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                TextField("Nota", text: $note, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($focusedField, equals: .note)
            }
            .padding(.vertical, 12)

            if !accounts.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pagato con")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(accounts) { account in
                                chip(
                                    title: account.name,
                                    symbol: account.symbolName,
                                    hex: account.colorHex,
                                    isSelected: selectedAccountID == account.id
                                ) {
                                    Haptics.tap()
                                    selectedAccountID = selectedAccountID == account.id ? nil : account.id
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollClipDisabled()
                }
                .padding(.vertical, 12)
            }
        }
        .soldoCard()
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label("Elimina spesa", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(SoldoTheme.danger)
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(editingExpense == nil ? "Salva spesa" : "Salva modifiche")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(SoldoTheme.accent)
        .disabled(parsedAmount == nil)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.bar)
    }

    private func chip(title: String, symbol: String, hex: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let color = Color(hex: hex)
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundStyle(isSelected ? .white : color)
            .background(isSelected ? color : color.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Amount entry

    private var displayAmount: String {
        let symbol = Money.symbol(for: settings.currencyCode)
        let text = amountText.isEmpty ? "0" : amountText
        return "\(text) \(symbol)"
    }

    private var dateLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Oggi, \(date.formatted(date: .omitted, time: .shortened))"
        }
        if calendar.isDateInYesterday(date) {
            return "Ieri, \(date.formatted(date: .omitted, time: .shortened))"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func appendDigit(_ digit: String) {
        Haptics.tap()
        // Cap the decimals at two, and don't let the integer part run away.
        if let separatorIndex = amountText.firstIndex(where: { $0 == "," }) {
            let decimals = amountText.distance(from: separatorIndex, to: amountText.endIndex) - 1
            guard decimals < 2 else { return }
        } else if amountText.count >= 9 {
            return
        }
        if amountText == "0" { amountText = "" }
        amountText.append(digit)
    }

    private func appendSeparator() {
        Haptics.tap()
        guard !amountText.contains(",") else { return }
        amountText = amountText.isEmpty ? "0," : amountText + ","
    }

    private func deleteLast() {
        Haptics.tap()
        guard !amountText.isEmpty else { return }
        amountText.removeLast()
    }

    // MARK: - Loading and saving

    private func loadInitialStateIfNeeded() {
        guard !didLoadInitialState else { return }
        didLoadInitialState = true

        if let expense = editingExpense {
            amountText = Money.machineString(expense.amount).replacingOccurrences(of: ".", with: ",")
            merchant = expense.merchant
            note = expense.note
            date = expense.date
            selectedCategoryID = expense.category?.id
            selectedAccountID = expense.account?.id
            return
        }

        if let draft = initialDraft {
            amountText = draft.amountText.replacingOccurrences(of: ".", with: ",")
            merchant = draft.merchant
            note = draft.note
            date = draft.date
            selectedCategoryID = draft.categoryID
            selectedAccountID = draft.accountID
        }

        selectedCategoryID = selectedCategoryID ?? settings.defaultCategoryID ?? categories.first?.id
        selectedAccountID = selectedAccountID ?? settings.defaultAccountID
    }

    private func save() {
        guard let amount = parsedAmount else { return }

        let category = categories.first { $0.id == selectedCategoryID }
        let account = accounts.first { $0.id == selectedAccountID }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let expense = editingExpense {
            expense.amount = amount
            expense.merchant = trimmedMerchant
            expense.note = trimmedNote
            expense.date = date
            expense.category = category
            expense.account = account
            expense.currencyCode = settings.currencyCode
            expense.touch()
        } else {
            let expense = Expense(
                amount: amount,
                currencyCode: settings.currencyCode,
                date: date,
                merchant: trimmedMerchant,
                note: trimmedNote,
                category: category,
                account: account
            )
            context.insert(expense)
        }

        try? context.save()
        coordinator.dataDidChange(context: context)
        Haptics.success()
        dismiss()
    }

    private func deleteExpense() {
        guard let expense = editingExpense else { return }
        context.deleteExpense(expense)
        coordinator.dataDidChange(context: context)
        Haptics.warning()
        dismiss()
    }
}

/// Numeric keypad tuned for one-handed use.
private struct Keypad: View {
    let onDigit: (String) -> Void
    let onSeparator: () -> Void
    let onDelete: () -> Void
    let onLongDelete: () -> Void

    private let rows: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [",", "0", "\u{232B}"],
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { value in
                        keyButton(value)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func keyButton(_ value: String) -> some View {
        Button {
            switch value {
            case ",": onSeparator()
            case "\u{232B}": onDelete()
            default: onDigit(value)
            }
        } label: {
            Group {
                if value == "\u{232B}" {
                    Image(systemName: "delete.left")
                        .font(.title2)
                } else {
                    Text(value)
                        .font(.system(size: 26, weight: .medium, design: .rounded))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                if value == "\u{232B}" { onLongDelete() }
            }
        )
    }
}
