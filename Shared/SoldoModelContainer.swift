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

    private static let storeFileName = "Soldo.store"

    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            : ModelConfiguration(schema: schema, url: storeURL())

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

    // MARK: - Where the database lives

    /// The App Group container when it is available, so an intent performed from
    /// Control Centre can write an expense without launching the app. Without the
    /// entitlement — which happens with some sideloading setups — the store stays
    /// in the app's own container and everything except that shortcut still works.
    static func storeURL() -> URL {
        guard let group = AppGroup.containerURL else { return legacyStoreURL() }
        let shared = group.appending(path: storeFileName)
        let fileManager = FileManager.default

        // Already moved.
        if fileManager.fileExists(atPath: shared.path(percentEncoded: false)) { return shared }

        // Nothing to move: this is a fresh install.
        guard let legacy = existingLegacyStoreURL() else { return shared }

        // If the copy does not fully succeed, keep using the store that is known to
        // be good rather than silently starting from an empty database.
        guard migrate(from: legacy, to: shared) else { return legacy }
        return shared
    }

    /// Where SwiftData put the store before the App Group move, if it is still there.
    ///
    /// `default.store` is SwiftData's own name, but the directory is scanned as well:
    /// getting this wrong would mean opening an empty database and looking, to the
    /// user, exactly like data loss.
    private static func existingLegacyStoreURL() -> URL? {
        let fileManager = FileManager.default
        let directory = applicationSupportDirectory

        let expected = directory.appending(path: "default.store")
        if fileManager.fileExists(atPath: expected.path(percentEncoded: false)) { return expected }

        let contents = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents.first { $0.pathExtension == "store" }
    }

    private static func legacyStoreURL() -> URL {
        applicationSupportDirectory.appending(path: "default.store")
    }

    private static var applicationSupportDirectory: URL {
        (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL.documentsDirectory
    }

    /// Copies an existing database into the shared container. The originals are
    /// never deleted: if anything goes wrong the previous store is still there.
    ///
    /// This runs before any `ModelContainer` is opened in this process, and the
    /// other process is not running when an intent fires, so the SQLite files
    /// (including the write-ahead log) are quiescent and safe to copy as a set.
    ///
    /// Returns false when the copy did not complete, in which case any partial
    /// result is removed so the next launch can retry from a clean state.
    private static func migrate(from legacy: URL, to shared: URL) -> Bool {
        let fileManager = FileManager.default
        let legacyPath = legacy.path(percentEncoded: false)
        let sharedPath = shared.path(percentEncoded: false)

        func discardPartialCopy() {
            for suffix in ["", "-wal", "-shm"] {
                try? fileManager.removeItem(at: URL(fileURLWithPath: sharedPath + suffix))
            }
        }

        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: legacyPath + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            do {
                try fileManager.copyItem(at: source, to: URL(fileURLWithPath: sharedPath + suffix))
            } catch {
                print("[Soldo] Store migration failed for \(source.lastPathComponent): \(error)")
                discardPartialCopy()
                return false
            }
        }

        guard fileManager.fileExists(atPath: sharedPath) else {
            discardPartialCopy()
            return false
        }

        print("[Soldo] Store migrated into the App Group container.")
        return true
    }

    // MARK: - Seeding

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
