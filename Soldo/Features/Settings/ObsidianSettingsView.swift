import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ObsidianSettingsView: View {
    @Environment(ObsidianVaultLink.self) private var vault
    @Environment(ObsidianSettingsStore.self) private var store
    @Environment(SyncCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var context

    @State private var isPickingVault = false
    @State private var isConfirmingRebuild = false
    @State private var alert: InfoAlert?
    @State private var accessCheck: Bool?

    struct InfoAlert: Identifiable {
        let id = UUID()
        var title: String
        var message: String
    }

    private var configuration: ObsidianConfiguration { store.configuration }

    var body: some View {
        @Bindable var store = store

        Form {
            vaultSection

            Section {
                Picker("Formato", selection: $store.configuration.mode) {
                    ForEach(ObsidianExportMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbolName).tag(mode)
                    }
                }
                .pickerStyle(.navigationLink)

                Text(configuration.mode.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Come scrivere le spese")
            } footer: {
                if let warning = configuration.mode.managedFileWarning {
                    Text(warning)
                }
            }

            modeOptionsSection

            Section("Anteprima") {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(previewText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.vertical, 4)
                }
                LabeledContent("Destinazione", value: configuration.destinationDescription)
                    .font(.caption)
            }

            Section {
                Toggle("Sincronizza automaticamente", isOn: $store.configuration.autoSync)
                Toggle("Scrivi anche un backup JSON", isOn: $store.configuration.writeBackupFile)
                if configuration.writeBackupFile {
                    TextField("Nome del backup", text: $store.configuration.backupFileName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
            } header: {
                Text("Automazione")
            } footer: {
                Text("Con la sincronizzazione automatica ogni spesa raggiunge il vault poco dopo il salvataggio.")
            }

            Section {
                Button {
                    Task { await coordinator.sync(context: context) }
                } label: {
                    Label("Sincronizza ora", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!vault.isConnected || coordinator.status.isSyncing)

                Button {
                    isConfirmingRebuild = true
                } label: {
                    Label("Riscrivi tutte le spese", systemImage: "arrow.clockwise")
                }
                .disabled(!vault.isConnected || coordinator.status.isSyncing)

                if case .failure(let message) = coordinator.status {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(SoldoTheme.danger)
                }
                if let last = coordinator.lastSyncDate {
                    LabeledContent("Ultima sincronizzazione", value: last.formatted(.relative(presentation: .named)))
                        .font(.caption)
                }
            } header: {
                Text("Azioni")
            }
        }
        .navigationTitle("Obsidian")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $isPickingVault, allowedContentTypes: [.folder]) { result in
            connectVault(result)
        }
        .confirmationDialog(
            "Riscrivere tutte le spese nel vault?",
            isPresented: $isConfirmingRebuild,
            titleVisibility: .visible
        ) {
            Button("Riscrivi tutto") {
                coordinator.markEverythingPending(context: context)
                Task { await coordinator.sync(context: context) }
            }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Utile dopo aver cambiato formato o cartella. Le note già presenti verranno aggiornate o ricreate.")
        }
        .alert(item: $alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var vaultSection: some View {
        Section {
            if vault.isConnected {
                HStack(spacing: 12) {
                    SymbolBadge(symbolName: "folder.fill", colorHex: "8E44AD")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vault.displayName ?? "Vault")
                            .font(.body.weight(.medium))
                        Text(vault.lastKnownPath ?? "")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.head)
                    }
                    Spacer()
                    if let accessCheck {
                        Image(systemName: accessCheck ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(accessCheck ? SoldoTheme.ink : SoldoTheme.danger)
                    }
                }

                Button("Cambia vault") { isPickingVault = true }
                Button("Verifica accesso") { verifyAccess() }
                Button("Scollega", role: .destructive) {
                    vault.disconnect()
                    accessCheck = nil
                }
            } else {
                Button {
                    isPickingVault = true
                } label: {
                    Label("Scegli la cartella del vault", systemImage: "folder.badge.plus")
                }
            }
        } header: {
            Text("Vault")
        } footer: {
            Text("Un vault Obsidian è una normale cartella. Scegli quella del vault — in iCloud Drive, dentro «Obsidian» in Su iPhone, o dove preferisci. Soldo scrive solo nella sottocartella che indichi qui sotto.")
        }
    }

    @ViewBuilder
    private var modeOptionsSection: some View {
        @Bindable var store = store

        switch configuration.mode {
        case .singleNote:
            Section("Percorso") {
                folderField
                TextField("Nome del file", text: $store.configuration.singleNoteFileName)
                    .autocorrectionDisabled()
            }

        case .csv:
            Section("Percorso") {
                folderField
                TextField("Nome del file", text: $store.configuration.csvFileName)
                    .autocorrectionDisabled()
            }

        case .notePerExpense:
            Section {
                folderField
                TextField("Nome del file", text: $store.configuration.noteFileNameTemplate)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Toggle("Includi corpo della nota", isOn: $store.configuration.includeNoteBody)
                TagsField(tags: $store.configuration.frontMatterTags)
            } header: {
                Text("Percorso e contenuto")
            } footer: {
                Text("Segnaposto disponibili: {{data}}, {{ora}}, {{importo}}, {{valuta}}, {{categoria}}, {{conto}}, {{esercente}}, {{id}}.")
            }

        case .dailyNote:
            Section {
                TextField("Cartella del diario", text: $store.configuration.dailyNoteFolder)
                    .autocorrectionDisabled()
                TextField("Formato della data", text: $store.configuration.dailyNoteDateFormat)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                TextField("Titolo della sezione", text: $store.configuration.dailyNoteHeading)
                    .autocorrectionDisabled()
            } header: {
                Text("Note giornaliere")
            } footer: {
                Text("Usa lo stesso formato del plugin Daily Notes di Obsidian (per esempio yyyy-MM-dd). Soldo aggiunge una riga sotto il titolo indicato, creando la nota se non esiste.")
            }
        }
    }

    private var folderField: some View {
        @Bindable var store = store
        return TextField("Cartella nel vault", text: $store.configuration.folderPath)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }

    // MARK: - Preview

    private var previewSample: ExpenseExportItem {
        ExpenseExportItem(
            id: UUID(uuidString: "6f1a2b3c-4d5e-6f70-8192-a3b4c5d6e7f8")!,
            amount: Decimal(string: "12.50")!,
            currencyCode: AppSettings.shared.currencyCode,
            date: .now,
            merchant: "Coop",
            note: "Pane e latte",
            categoryName: "Spesa",
            accountName: "Carta"
        )
    }

    private var previewText: String {
        switch configuration.mode {
        case .singleNote:
            return ObsidianRenderer.singleNoteDocument(items: [previewSample])
        case .csv:
            return ObsidianRenderer.csvDocument(items: [previewSample])
        case .notePerExpense:
            return ObsidianRenderer.noteDocument(for: previewSample, configuration: configuration)
        case .dailyNote:
            let base = ObsidianRenderer.emptyDailyNote(for: .now, configuration: configuration)
            return ObsidianSyncEngine.upsert(
                line: ObsidianRenderer.dailyNoteLine(for: previewSample),
                marker: ObsidianRenderer.blockRef(for: previewSample.id),
                heading: configuration.dailyNoteHeading,
                in: base
            )
        }
    }

    // MARK: - Actions

    private func connectVault(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            try vault.connect(to: url)
            accessCheck = true
            coordinator.markEverythingPending(context: context)
            Task { await coordinator.sync(context: context) }
        } catch {
            alert = InfoAlert(title: "Vault non collegato", message: error.localizedDescription)
            accessCheck = false
        }
    }

    private func verifyAccess() {
        switch vault.verifyAccess() {
        case .success:
            accessCheck = true
            alert = InfoAlert(title: "Accesso OK", message: "Soldo può leggere e scrivere nel vault.")
        case .failure(let error):
            accessCheck = false
            alert = InfoAlert(title: "Accesso non riuscito", message: error.localizedDescription)
        }
    }
}

/// Small editor for the YAML tags written into each note.
struct TagsField: View {
    @Binding var tags: [String]
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tag")
                Spacer()
                TextField("spesa, finanze", text: $text)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: text) { _, newValue in
                        tags = newValue
                            .split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                    }
            }
        }
        .onAppear {
            if text.isEmpty { text = tags.joined(separator: ", ") }
        }
    }
}
