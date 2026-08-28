import SwiftData
import SwiftUI

/// Compact Obsidian status shown on Home: whether a vault is linked, how many
/// expenses are still queued, and the outcome of the last run.
struct SyncStatusBanner: View {
    @Environment(SyncCoordinator.self) private var coordinator
    @Environment(ObsidianVaultLink.self) private var vault
    @Environment(ObsidianSettingsStore.self) private var obsidian
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var context

    @Query private var pending: [Expense]

    init() {
        let pendingRaw = SyncState.pending.rawValue
        let failedRaw = SyncState.failed.rawValue
        _pending = Query(filter: #Predicate<Expense> { expense in
            expense.syncStateRaw == pendingRaw || expense.syncStateRaw == failedRaw
        })
    }

    var body: some View {
        Group {
            if !vault.isConnected {
                banner(
                    symbol: "link.badge.plus",
                    tint: SoldoTheme.warning,
                    title: "Collega il tuo vault Obsidian",
                    detail: "Scegli la cartella del vault per esportare le spese in Markdown.",
                    action: "Collega"
                ) {
                    router.selectedTab = .settings
                }
            } else {
                switch coordinator.status {
                case .syncing:
                    banner(
                        symbol: "arrow.triangle.2.circlepath",
                        tint: SoldoTheme.accent,
                        title: "Sincronizzazione in corso…",
                        detail: vault.displayName ?? "Vault",
                        action: nil,
                        showsProgress: true
                    ) {}

                case .failure(let message):
                    banner(
                        symbol: "exclamationmark.triangle.fill",
                        tint: SoldoTheme.danger,
                        title: "Sincronizzazione non riuscita",
                        detail: message,
                        action: "Riprova"
                    ) {
                        Task { await coordinator.sync(context: context) }
                    }

                default:
                    if !pending.isEmpty {
                        banner(
                            symbol: "clock.arrow.circlepath",
                            tint: SoldoTheme.warning,
                            title: "\(pending.count) \(pending.count == 1 ? "spesa da sincronizzare" : "spese da sincronizzare")",
                            detail: obsidian.configuration.destinationDescription,
                            action: "Sincronizza"
                        ) {
                            Task { await coordinator.sync(context: context) }
                        }
                    } else if let last = coordinator.lastSyncDate {
                        banner(
                            symbol: "checkmark.circle.fill",
                            tint: SoldoTheme.accent,
                            title: "Tutto sincronizzato su Obsidian",
                            detail: "Ultimo aggiornamento \(last.formatted(.relative(presentation: .named)))",
                            action: nil
                        ) {}
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func banner(
        symbol: String,
        tint: Color,
        title: String,
        detail: String,
        action: String?,
        showsProgress: Bool = false,
        perform: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            if showsProgress {
                ProgressView().frame(width: 22)
            } else {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            if let action {
                Button(action, action: perform)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(tint)
            }
        }
        .soldoCard(padding: 12)
    }
}
