import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ObsidianVaultLink.self) private var vault
    @Environment(SyncCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var context

    @State private var page = 0
    @State private var isPickingVault = false
    @State private var vaultError: String?

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                obsidianPage.tag(1)
                readyPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: advance) {
                Text(page == 2 ? "Inizia" : "Avanti")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(SoldoTheme.accent)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            if page < 2 {
                Button("Salta") { finish() }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .fileImporter(isPresented: $isPickingVault, allowedContentTypes: [.folder]) { result in
            do {
                try vault.connect(to: result.get())
                vaultError = nil
                page = 2
            } catch {
                vaultError = error.localizedDescription
            }
        }
    }

    private var welcomePage: some View {
        page(
            symbol: "eurosign.circle.fill",
            title: "Benvenuto in Soldo",
            subtitle: "Un modo veloce e minimale per segnare le spese. Niente account, niente abbonamenti, niente pubblicità."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                bullet("bolt.fill", "Registri una spesa in due secondi con il tastierino")
                bullet("square.stack.3d.up.fill", "Le spese finiscono nel tuo vault Obsidian, in Markdown")
                bullet("rectangle.3.group.fill", "Widget e comandi rapidi per non aprire nemmeno l'app")
            }
            .padding(.top, 8)
        }
    }

    private var obsidianPage: some View {
        page(
            symbol: "square.stack.3d.up.fill",
            title: "Collega il vault",
            subtitle: "Scegli la cartella del tuo vault Obsidian. Soldo scriverà le spese come normali file Markdown, che puoi leggere e modificare ovunque."
        ) {
            VStack(spacing: 12) {
                if vault.isConnected {
                    Label(vault.displayName ?? "Vault collegato", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(SoldoTheme.accent)
                        .font(.subheadline.weight(.medium))
                }

                Button {
                    isPickingVault = true
                } label: {
                    Label(vault.isConnected ? "Cambia vault" : "Scegli la cartella", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(SoldoTheme.accent)

                if let vaultError {
                    Text(vaultError)
                        .font(.caption)
                        .foregroundStyle(SoldoTheme.danger)
                        .multilineTextAlignment(.center)
                }

                Text("Puoi farlo anche dopo, da Impostazioni › Obsidian.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private var readyPage: some View {
        page(
            symbol: "checkmark.seal.fill",
            title: "Tutto pronto",
            subtitle: "I tuoi dati restano sul telefono e nel tuo vault. Nessun server, nessuna sottoscrizione."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                bullet("hand.tap.fill", "Tocca + per la prima spesa")
                bullet("gearshape.fill", "Da Impostazioni scegli formato, cartella e valuta")
                bullet("bolt.fill", "In Comandi rapidi trovi l'azione «Aggiungi spesa»")
            }
            .padding(.top, 8)
        }
    }

    private func page<Content: View>(
        symbol: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 18) {
            Spacer(minLength: 20)
            Image(systemName: symbol)
                .font(.system(size: 56))
                .foregroundStyle(SoldoTheme.accent)
            Text(title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            content()
            Spacer(minLength: 40)
        }
        .padding(.horizontal, 28)
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(SoldoTheme.accent)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func advance() {
        if page < 2 {
            withAnimation { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        settings.hasCompletedOnboarding = true
        coordinator.refreshWidgetSnapshot(context: context)
    }
}
