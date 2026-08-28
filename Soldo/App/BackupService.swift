import Foundation
import SwiftData

/// JSON export and import of the whole database.
///
/// Soldo has no account and no server, so this file is the way to move data to a
/// new phone — drop it in the vault (which usually lives in iCloud Drive) or share
/// it anywhere else.
enum BackupService {

    struct Backup: Codable {
        var version: Int
        var app: String
        var exportedAt: Date
        var currencyCode: String
        var categories: [CategoryDTO]
        var accounts: [AccountDTO]
        var expenses: [ExpenseDTO]
    }

    struct CategoryDTO: Codable {
        var id: UUID
        var name: String
        var symbolName: String
        var colorHex: String
        var sortIndex: Int
        var isArchived: Bool
    }

    struct AccountDTO: Codable {
        var id: UUID
        var name: String
        var symbolName: String
        var colorHex: String
        var sortIndex: Int
        var isArchived: Bool
    }

    struct ExpenseDTO: Codable {
        var id: UUID
        var amount: Decimal
        var currencyCode: String
        var date: Date
        var merchant: String
        var note: String
        var categoryID: UUID?
        var accountID: UUID?
        var createdAt: Date
        var updatedAt: Date
    }

    static let currentVersion = 1

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Export

    @MainActor
    static func makeBackup(context: ModelContext) throws -> Backup {
        let categories = (try? context.fetch(FetchDescriptor<SpendingCategory>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<PaymentAccount>())) ?? []
        let expenses = (try? context.fetch(
            FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )) ?? []

        return Backup(
            version: currentVersion,
            app: "Soldo",
            exportedAt: .now,
            currencyCode: AppSettings.shared.currencyCode,
            categories: categories.map {
                CategoryDTO(id: $0.id, name: $0.name, symbolName: $0.symbolName, colorHex: $0.colorHex, sortIndex: $0.sortIndex, isArchived: $0.isArchived)
            },
            accounts: accounts.map {
                AccountDTO(id: $0.id, name: $0.name, symbolName: $0.symbolName, colorHex: $0.colorHex, sortIndex: $0.sortIndex, isArchived: $0.isArchived)
            },
            expenses: expenses.map {
                ExpenseDTO(
                    id: $0.id,
                    amount: $0.amount,
                    currencyCode: $0.currencyCode,
                    date: $0.date,
                    merchant: $0.merchant,
                    note: $0.note,
                    categoryID: $0.category?.id,
                    accountID: $0.account?.id,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            }
        )
    }

    @MainActor
    static func makeBackupData(context: ModelContext) throws -> Data {
        try encoder.encode(makeBackup(context: context))
    }

    /// Writes the backup to a temporary file so it can go through the share sheet.
    @MainActor
    static func exportToTemporaryFile(context: ModelContext) throws -> URL {
        let data = try makeBackupData(context: context)
        let name = "Soldo-\(ObsidianRenderer.isoDay(.now)).json"
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import

    struct ImportResult {
        var categoriesAdded: Int
        var accountsAdded: Int
        var expensesAdded: Int
        var expensesSkipped: Int
    }

    /// Merges a backup into the existing database. Anything already present, matched
    /// by id, is left untouched — importing twice is harmless.
    @MainActor
    @discardableResult
    static func restore(from data: Data, context: ModelContext) throws -> ImportResult {
        let backup = try decoder.decode(Backup.self, from: data)

        var result = ImportResult(categoriesAdded: 0, accountsAdded: 0, expensesAdded: 0, expensesSkipped: 0)

        let existingCategories = (try? context.fetch(FetchDescriptor<SpendingCategory>())) ?? []
        let existingAccounts = (try? context.fetch(FetchDescriptor<PaymentAccount>())) ?? []
        let existingExpenseIDs = Set(((try? context.fetch(FetchDescriptor<Expense>())) ?? []).map(\.id))

        var categoriesByID = Dictionary(uniqueKeysWithValues: existingCategories.map { ($0.id, $0) })
        var accountsByID = Dictionary(uniqueKeysWithValues: existingAccounts.map { ($0.id, $0) })

        for dto in backup.categories where categoriesByID[dto.id] == nil {
            let category = SpendingCategory(
                id: dto.id,
                name: dto.name,
                symbolName: dto.symbolName,
                colorHex: dto.colorHex,
                sortIndex: dto.sortIndex,
                isArchived: dto.isArchived
            )
            context.insert(category)
            categoriesByID[dto.id] = category
            result.categoriesAdded += 1
        }

        for dto in backup.accounts where accountsByID[dto.id] == nil {
            let account = PaymentAccount(
                id: dto.id,
                name: dto.name,
                symbolName: dto.symbolName,
                colorHex: dto.colorHex,
                sortIndex: dto.sortIndex,
                isArchived: dto.isArchived
            )
            context.insert(account)
            accountsByID[dto.id] = account
            result.accountsAdded += 1
        }

        for dto in backup.expenses {
            guard !existingExpenseIDs.contains(dto.id) else {
                result.expensesSkipped += 1
                continue
            }
            let expense = Expense(
                id: dto.id,
                amount: dto.amount,
                currencyCode: dto.currencyCode,
                date: dto.date,
                merchant: dto.merchant,
                note: dto.note,
                category: dto.categoryID.flatMap { categoriesByID[$0] },
                account: dto.accountID.flatMap { accountsByID[$0] }
            )
            expense.createdAt = dto.createdAt
            expense.updatedAt = dto.updatedAt
            context.insert(expense)
            result.expensesAdded += 1
        }

        try context.save()
        return result
    }
}
