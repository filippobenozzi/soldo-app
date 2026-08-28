import SwiftData
import SwiftUI

struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Environment(SyncCoordinator.self) private var coordinator
    @Query(sort: \SpendingCategory.sortIndex) private var categories: [SpendingCategory]

    /// One binding, because two `.sheet` modifiers on the same view do not both
    /// work — only one of them is ever honoured.
    @State private var editor: Editor?

    private enum Editor: Identifiable {
        case new
        case existing(SpendingCategory)

        var id: String {
            switch self {
            case .new: "new"
            case .existing(let category): category.id.uuidString
            }
        }

        var category: SpendingCategory? {
            switch self {
            case .new: nil
            case .existing(let category): category
            }
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    Button {
                        editor = .existing(category)
                    } label: {
                        HStack(spacing: 12) {
                            SymbolBadge(symbolName: category.symbolName, colorHex: category.colorHex)
                            Text(category.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if category.isArchived {
                                Text("archiviata")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("\(category.expenses?.count ?? 0)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove(perform: move)
                .onDelete(perform: delete)
            } footer: {
                Text("Eliminando una categoria le spese collegate restano, ma senza categoria. Trascina per riordinare.")
            }
        }
        .navigationTitle("Categorie")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editor = .new } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .topBarLeading) { EditButton() }
        }
        .sheet(item: $editor) { editor in
            CategoryEditorView(category: editor.category)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = categories
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, category) in reordered.enumerated() {
            category.sortIndex = index
        }
        try? context.save()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(categories[index])
        }
        try? context.save()
        coordinator.dataDidChange(context: context)
    }
}

struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SyncCoordinator.self) private var coordinator
    @Query(sort: \SpendingCategory.sortIndex) private var categories: [SpendingCategory]

    let category: SpendingCategory?

    @State private var name = ""
    @State private var symbolName = "tag.fill"
    @State private var colorHex = "27AE60"
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

                if category != nil {
                    Section {
                        Toggle("Archivia", isOn: $isArchived)
                            .scheiSwitch()
                    } footer: {
                        Text("Le categorie archiviate non compaiono più quando registri una spesa, ma restano sullo storico.")
                    }
                }

                Section {
                    SymbolColorPicker(symbolName: $symbolName, colorHex: $colorHex)
                }
            }
            .navigationTitle(category == nil ? "Nuova categoria" : "Modifica categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
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
        guard let category else {
            colorHex = ScheiPalette.random()
            return
        }
        name = category.name
        symbolName = category.symbolName
        colorHex = category.colorHex
        isArchived = category.isArchived
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let category {
            category.name = trimmed
            category.symbolName = symbolName
            category.colorHex = colorHex
            category.isArchived = isArchived
            // Renaming a category changes what every linked expense exports.
            for expense in category.expenses ?? [] {
                expense.touch()
            }
        } else {
            context.insert(
                SpendingCategory(
                    name: trimmed,
                    symbolName: symbolName,
                    colorHex: colorHex,
                    sortIndex: (categories.map(\.sortIndex).max() ?? -1) + 1
                )
            )
        }
        try? context.save()
        coordinator.dataDidChange(context: context)
        dismiss()
    }
}
