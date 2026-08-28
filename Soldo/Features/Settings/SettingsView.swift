import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ObsidianVaultLink.self) private var vault
    @Environment(ObsidianSettingsStore.self) private var obsidian
    @Environment(SyncCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var context

    @State private var budgetText = ""
    @State private var isImportingBackup = false
    @State private var exportURL: URL?
    @State private var alert: SettingsAlert?

    struct SettingsAlert: Identifiable {
        let id = UUID()
        var title: String
        var message: String
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ObsidianSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            SymbolBadge(symbolName: "square.stack.3d.up.fill", colorHex: "8E44AD")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Obsidian")
                                Text(vault.isConnected ? (vault.displayName ?? "Vault collegato") : "Non collegato")
                                    .font(.caption)
                                    .foregroundStyle(vault.isConnected ? SoldoTheme.accent : .secondary)
                            }
                        }
                    }
                } header: {
                    Text("Sincronizzazione")
                } footer: {
                    Text("Soldo scrive le spese direttamente nei file del tuo vault. Nessun account, nessun server.")
                }

                Section("Generale") {
                    Picker("Valuta", selection: $settings.currencyCode) {
                        ForEach(Money.commonCurrencyCodes, id: \.self) { code in
                            Text(Money.currencyDisplayName(code)).tag(code)
                        }
                    }

                    HStack {
                        Text("Budget mensile")
                        Spacer()
                        TextField("nessuno", text: $budgetText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                            .onChange(of: budgetText) { _, newValue in
                                settings.monthlyBudget = Money.parse(newValue)
                            }
                        Text(Money.symbol(for: settings.currencyCode))
                            .foregroundStyle(.secondary)
                    }

                    Picker("Aspetto", selection: $settings.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }

                    Toggle("Feedback aptico", isOn: $settings.hapticsEnabled)
                }

                Section("Dati") {
                    NavigationLink {
                        CategoriesView()
                    } label: {
                        Label("Categorie", systemImage: "tag.fill")
                    }

                    NavigationLink {
                        AccountsView()
                    } label: {
                        Label("Conti e metodi di pagamento", systemImage: "creditcard.fill")
                    }

                    Button {
                        exportBackup()
                    } label: {
                        Label("Esporta backup JSON", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        isImportingBackup = true
                    } label: {
                        Label("Importa backup JSON", systemImage: "square.and.arrow.down")
                    }
                }

                Section {
                    NavigationLink {
                        ShortcutsHelpView()
                    } label: {
                        Label("Comandi rapidi e Apple Pay", systemImage: "bolt.fill")
                    }
                } header: {
                    Text("Automazioni")
                } footer: {
                    Text("Registra una spesa con il Back Tap, il tasto Azione o subito dopo un pagamento con Apple Pay.")
                }

                Section {
                    LabeledContent("Versione", value: appVersion)
                    Link(destination: URL(string: "https://github.com/filippobenozzi/soldo-app")!) {
                        Label("Codice sorgente su GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } header: {
                    Text("Info")
                } footer: {
                    Text("Soldo non ha abbonamenti, pubblicità né tracciamento. I dati restano sul telefono e nel tuo vault.")
                }
            }
            .navigationTitle("Impostazioni")
            .onAppear {
                if let budget = settings.monthlyBudget, budget > 0, budgetText.isEmpty {
                    budgetText = Money.machineString(budget).replacingOccurrences(of: ".", with: ",")
                }
            }
            .fileImporter(isPresented: $isImportingBackup, allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
            .sheet(item: Binding(
                get: { exportURL.map { ExportPayload(url: $0) } },
                set: { if $0 == nil { exportURL = nil } }
            )) { payload in
                ShareSheet(items: [payload.url])
            }
            .alert(item: $alert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private struct ExportPayload: Identifiable {
        let id = UUID()
        let url: URL
    }

    private func exportBackup() {
        do {
            exportURL = try BackupService.exportToTemporaryFile(context: context)
        } catch {
            alert = SettingsAlert(title: "Export non riuscito", message: error.localizedDescription)
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let outcome = try BackupService.restore(from: data, context: context)
            coordinator.dataDidChange(context: context)
            alert = SettingsAlert(
                title: "Backup importato",
                message: "\(outcome.expensesAdded) spese aggiunte, \(outcome.expensesSkipped) già presenti."
            )
        } catch {
            alert = SettingsAlert(title: "Import non riuscito", message: error.localizedDescription)
        }
    }
}

/// UIKit share sheet, still the simplest way to hand a file to another app.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
