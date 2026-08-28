import Foundation
import SwiftData

enum SoldoModelContainer {
    /// One container for the whole process: the app UI and any App Intent that iOS
    /// runs in the background must not open the same store twice.
    static let shared = make()

    static let schema = Schema([
        Expense.self,
        SpendingCategory.self,
        PaymentAccount.self,
        PendingVaultDeletion.self,
    ])

    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A corrupt store must not brick the app: fall back to memory so the user
            // can still reach Settings and re-import a backup.
            print("[Soldo] Persistent store unavailable (\(error)); falling back to in-memory.")
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            // swiftlint:disable:next force_try
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }

    /// Creates the default categories and accounts the first time the app runs.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let categoryCount = (try? context.fetchCount(FetchDescriptor<SpendingCategory>())) ?? 0
        if categoryCount == 0 {
            for (index, item) in SpendingCategory.defaults.enumerated() {
                context.insert(
                    SpendingCategory(name: item.name, symbolName: item.symbol, colorHex: item.hex, sortIndex: index)
                )
            }
        }

        let accountCount = (try? context.fetchCount(FetchDescriptor<PaymentAccount>())) ?? 0
        if accountCount == 0 {
            for (index, item) in PaymentAccount.defaults.enumerated() {
                context.insert(
                    PaymentAccount(name: item.name, symbolName: item.symbol, colorHex: item.hex, sortIndex: index)
                )
            }
        }

        if context.hasChanges {
            try? context.save()
        }
    }
}
