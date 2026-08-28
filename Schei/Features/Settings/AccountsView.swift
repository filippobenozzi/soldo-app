import SwiftData
import SwiftUI

struct AccountsView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncCoordinator.self) private var coordinator
    @Query(sort: \PaymentAccount.sortIndex) private var accounts: [PaymentAccount]

    /// One binding, because two `.sheet` modifiers on the same view do not both
    /// work — only one of them is ever honoured.
    @State private var editor: Editor?

    private enum Editor: Identifiable {
        case new
        case existing(PaymentAccount)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let account): account.id.uuidString
            }
        }

        var account: PaymentAccount? {
            switch self {
            case .new: nil
            case .existing(let account): account
            }
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(accounts) { account in
                    Button {
                        editor = .existing(account)
                    } label: {
                        HStack(spacing: 12) {
                            SymbolBadge(symbolName: account.symbolName, colorHex: account.colorHex)
                            Text(account.name).foregroundStyle(.primary)
                            Spacer()
                            Text("\(account.expenses?.count ?? 0)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            } footer: {
                Text("Contanti, carte, conti: come preferisci suddividere i pagamenti.")
            }
        }
        .navigationTitle("Conti")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editor = .new } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarLeading) { EditButton() }
        }
        .sheet(item: $editor) { editor in
            AccountEditorView(account: editor.account)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = accounts
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, account) in reordered.enumerated() {
            account.sortIndex = index
        }
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(accounts[index])
        }
        try? context.save()
        coordinator.dataDidChange(context: context)
    }
}

struct AccountEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SyncCoordinator.self) private var coordinator
    @Query(sort: \PaymentAccount.sortIndex) private var accounts: [PaymentAccount]

    let account: PaymentAccount?

    @State private var name = ""
    @State private var symbolName = "creditcard.fill"
    @State private var colorHex = "2E86DE"
    @State private var isArchived = false
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        SymbolBadge(symbolName: symbolName, colorHex: colorHex, size: 44)
                        TextField("Nome", text: $name)
                            .font(.title3)
                    }
                }

                if account != nil {
                    Section {
                        Toggle("Archivia", isOn: $isArchived)
                            .scheiSwitch()
                    }
                }

                Section {
                    SymbolColorPicker(symbolName: $symbolName, colorHex: $colorHex)
                }
            }
            .navigationTitle(account == nil ? "Nuovo conto" : "Modifica conto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let account else {
            colorHex = ScheiPalette.random()
            return
        }
        name = account.name
        symbolName = account.symbolName
        colorHex = account.colorHex
        isArchived = account.isArchived
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let account {
            account.name = trimmed
            account.symbolName = symbolName
            account.colorHex = colorHex
            account.isArchived = isArchived
            for expense in account.expenses ?? [] {
                expense.touch()
            }
        } else {
            context.insert(
                PaymentAccount(
                    name: trimmed,
                    symbolName: symbolName,
                    colorHex: colorHex,
                    sortIndex: (accounts.map(\.sortIndex).max() ?? -1) + 1
                )
            )
        }
        try? context.save()
        coordinator.dataDidChange(context: context)
        dismiss()
    }
}
