import Foundation
import Observation
import SwiftData
import WidgetKit

/// Drives Obsidian sync and keeps the widget snapshot fresh.
///
/// Everything that talks to SwiftData happens on the main actor; the actual file
/// writing is handed to `ObsidianSyncEngine`, which serialises it off the main thread.
@MainActor
@Observable
final class SyncCoordinator {
    static let shared = SyncCoordinator()

    enum Status: Equatable {
        case idle
        case syncing
        case success(date: Date, files: Int)
        case failure(String)

        var isSyncing: Bool { self == .syncing }
    }

    var status: Status = .idle
    var lastSyncDate: Date? {
        didSet { AppGroup.defaults.set(lastSyncDate?.timeIntervalSince1970 ?? 0, forKey: "obsidian.lastSync") }
    }

    private let vault: ObsidianVaultLink
    private let settingsStore: ObsidianSettingsStore
    private let engine: ObsidianSyncEngine
    private var debounceTask: Task<Void, Never>?

    init(
        vault: ObsidianVaultLink = .shared,
        settingsStore: ObsidianSettingsStore = .shared,
        engine: ObsidianSyncEngine = .shared
    ) {
        self.vault = vault
        self.settingsStore = settingsStore
        self.engine = engine
        let stored = AppGroup.defaults.double(forKey: "obsidian.lastSync")
        self.lastSyncDate = stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    // MARK: - Entry points

    /// Called after every change. Refreshes the widget immediately and, when auto
    /// sync is on, syncs the vault after a short debounce so a burst of edits
    /// results in a single write.
    func dataDidChange(context: ModelContext) {
        refreshWidgetSnapshot(context: context)

        guard settingsStore.configuration.autoSync, vault.isConnected else { return }

        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await self?.sync(context: context)
        }
    }

    /// Full sync, driven by the user or by the app becoming active.
    func sync(context: ModelContext) async {
        guard vault.isConnected else {
            status = .failure(ObsidianError.noVaultSelected.localizedDescription)
            return
        }
        guard !status.isSyncing else { return }

        status = .syncing
        let configuration = settingsStore.configuration

        let expenses = fetchAllExpenses(context: context)
        let deletionRecords = fetchPendingDeletions(context: context)

        let items = expenses.map { expense in
            ExpenseExportItem(
                id: expense.id,
                amount: expense.amount,
                currencyCode: expense.currencyCode,
                date: expense.date,
                merchant: expense.merchant,
                note: expense.note,
                categoryName: expense.category?.name,
                accountName: expense.account?.name,
                placeName: expense.placeName,
                latitude: expense.latitude,
                longitude: expense.longitude,
                needsWrite: expense.syncState != .synced,
                existingRelativePath: expense.obsidianRelativePath
            )
        }

        let deletions = deletionRecords.map {
            ExpenseDeletionItem(expenseID: $0.expenseID, date: $0.expenseDate, relativePath: $0.relativePath)
        }

        let outcome = await engine.sync(items: items, deletions: deletions, configuration: configuration)

        apply(outcome: outcome, to: expenses, deletionRecords: deletionRecords, context: context)

        if configuration.writeBackupFile {
            if let data = try? BackupService.makeBackupData(context: context) {
                _ = await engine.writeBackup(data: data, configuration: configuration)
            }
        }

        if let fatal = outcome.fatalError {
            status = .failure(fatal)
        } else if let firstFailure = outcome.failed.values.first {
            status = .failure(firstFailure)
        } else {
            lastSyncDate = .now
            status = .success(date: .now, files: Set(outcome.filesTouched).count)
        }

        refreshWidgetSnapshot(context: context)
    }

    /// Forces every expense to be rewritten on the next run.
    func markEverythingPending(context: ModelContext) {
        for expense in fetchAllExpenses(context: context) {
            expense.syncState = .pending
        }
        try? context.save()
    }

    // MARK: - Applying results

    private func apply(
        outcome: ObsidianSyncOutcome,
        to expenses: [Expense],
        deletionRecords: [PendingVaultDeletion],
        context: ModelContext
    ) {
        let synced = outcome.allSynced

        for expense in expenses {
            if let message = outcome.failed[expense.id] {
                expense.syncState = .failed
                expense.syncErrorMessage = message
            } else if synced.contains(expense.id) {
                expense.syncState = .synced
                expense.syncedAt = .now
                expense.syncErrorMessage = nil
                if let path = outcome.syncedWithPath[expense.id] {
                    expense.obsidianRelativePath = path
                }
            }
        }

        for record in deletionRecords where outcome.deleted.contains(record.expenseID) {
            context.delete(record)
        }

        // Whole-file modes rewrite everything, so stale deletions are already gone.
        if settingsStore.configuration.mode.rebuildsWholeFile, outcome.fatalError == nil {
            for record in deletionRecords {
                context.delete(record)
            }
        }

        try? context.save()
    }

    // MARK: - Widget

    func refreshWidgetSnapshot(context: ModelContext) {
        let expenses = fetchAllExpenses(context: context)
        let settings = AppSettings.shared

        let recent = expenses.prefix(6).map { expense in
            WidgetSnapshot.Entry(
                id: expense.id,
                title: expense.displayTitle,
                amount: expense.amount,
                date: expense.date,
                symbolName: expense.category?.symbolName ?? "eurosign.circle.fill",
                colorHex: expense.category?.colorHex ?? "27AE60"
            )
        }

        let monthExpenses = expenses.filter { SpendingPeriod.month.contains($0.date) }
        let topCategories = SpendingSummary.byCategory(monthExpenses).prefix(4).map {
            WidgetSnapshot.CategorySlice(
                id: $0.id,
                name: $0.name,
                amount: $0.amount,
                symbolName: $0.symbolName,
                colorHex: $0.colorHex
            )
        }

        let snapshot = WidgetSnapshot(
            currencyCode: settings.currencyCode,
            todayTotal: SpendingSummary.total(expenses, in: .today),
            weekTotal: SpendingSummary.total(expenses, in: .week),
            monthTotal: SpendingSummary.total(monthExpenses),
            monthlyBudget: settings.monthlyBudget,
            recent: Array(recent),
            topCategories: Array(topCategories),
            pendingSyncCount: expenses.filter { $0.syncState == .pending || $0.syncState == .failed }.count,
            vaultConnected: vault.isConnected,
            generatedAt: .now,
            useCategoryColors: settings.useCategoryColors
        )

        WidgetSnapshotStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Fetching

    private func fetchAllExpenses(context: ModelContext) -> [Expense] {
        let descriptor = FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchPendingDeletions(context: ModelContext) -> [PendingVaultDeletion] {
        let descriptor = FetchDescriptor<PendingVaultDeletion>(sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }
}

// MARK: - Mutations that keep sync bookkeeping correct

extension ModelContext {
    /// Deletes an expense and records what has to be removed from the vault.
    @MainActor
    func deleteExpense(_ expense: Expense) {
        insert(
            PendingVaultDeletion(
                expenseID: expense.id,
                relativePath: expense.obsidianRelativePath,
                expenseDate: expense.date
            )
        )
        delete(expense)
        try? save()
    }
}
