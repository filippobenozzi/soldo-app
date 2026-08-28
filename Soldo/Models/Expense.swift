import Foundation
import SwiftData

enum SyncState: String, Codable, CaseIterable {
    /// Waiting to be written to the vault.
    case pending
    /// Written to the vault at least once, and unchanged since.
    case synced
    /// The last write attempt failed; the error is kept on the expense.
    case failed
    /// Vault sync is off, so this expense is not queued for anything.
    case off
}

@Model
final class Expense {
    var id: UUID = UUID()
    var amount: Decimal = Decimal.zero
    var currencyCode: String = Money.defaultCurrencyCode
    var date: Date = Date.now
    /// Where the money went — shop, merchant, person.
    var merchant: String = ""
    var note: String = ""
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    var category: SpendingCategory?
    var account: PaymentAccount?

    // MARK: Obsidian sync bookkeeping

    var syncStateRaw: String = SyncState.pending.rawValue
    var syncedAt: Date?
    var syncErrorMessage: String?
    /// Vault-relative path of the note this expense was written to, when the
    /// export mode produces one file per expense.
    var obsidianRelativePath: String?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        currencyCode: String = Money.defaultCurrencyCode,
        date: Date = .now,
        merchant: String = "",
        note: String = "",
        category: SpendingCategory? = nil,
        account: PaymentAccount? = nil
    ) {
        self.id = id
        self.amount = amount
        self.currencyCode = currencyCode
        self.date = date
        self.merchant = merchant
        self.note = note
        self.category = category
        self.account = account
        self.createdAt = .now
        self.updatedAt = .now
        self.syncStateRaw = SyncState.pending.rawValue
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .pending }
        set { syncStateRaw = newValue.rawValue }
    }

    var displayTitle: String {
        if !merchant.trimmingCharacters(in: .whitespaces).isEmpty { return merchant }
        if let name = category?.name, !name.isEmpty { return name }
        return "Spesa"
    }

    var formattedAmount: String {
        Money.string(amount, currencyCode: currencyCode)
    }

    /// Marks the expense as edited, so the next sync run picks it up again.
    func touch() {
        updatedAt = .now
        if syncState != .off {
            syncState = .pending
        }
    }
}
