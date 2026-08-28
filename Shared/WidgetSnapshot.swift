import Foundation

/// A flat, Codable picture of the user's spending that the app writes after every
/// change and the widget extension reads. Going through a JSON file in the App Group
/// container keeps the widget free of any SwiftData or store setup.
struct WidgetSnapshot: Codable, Equatable {
    struct Entry: Codable, Equatable, Identifiable {
        var id: UUID
        var title: String
        var amount: Decimal
        var date: Date
        var symbolName: String
        var colorHex: String
    }

    struct CategorySlice: Codable, Equatable, Identifiable {
        var id: UUID
        var name: String
        var amount: Decimal
        var symbolName: String
        var colorHex: String
    }

    var currencyCode: String
    var todayTotal: Decimal
    var weekTotal: Decimal
    var monthTotal: Decimal
    var monthlyBudget: Decimal?
    var recent: [Entry]
    var topCategories: [CategorySlice]
    var pendingSyncCount: Int
    var vaultConnected: Bool
    var generatedAt: Date

    static let empty = WidgetSnapshot(
        currencyCode: Money.defaultCurrencyCode,
        todayTotal: 0,
        weekTotal: 0,
        monthTotal: 0,
        monthlyBudget: nil,
        recent: [],
        topCategories: [],
        pendingSyncCount: 0,
        vaultConnected: false,
        generatedAt: .distantPast
    )

    /// Sample data for widget previews and the widget gallery.
    static let placeholder = WidgetSnapshot(
        currencyCode: "EUR",
        todayTotal: Decimal(string: "18.40")!,
        weekTotal: Decimal(string: "126.90")!,
        monthTotal: Decimal(string: "742.35")!,
        monthlyBudget: Decimal(string: "1200")!,
        recent: [
            Entry(id: UUID(), title: "Supermercato", amount: Decimal(string: "34.20")!, date: .now, symbolName: "cart.fill", colorHex: "27AE60"),
            Entry(id: UUID(), title: "Caffè", amount: Decimal(string: "1.30")!, date: .now.addingTimeInterval(-7200), symbolName: "cup.and.saucer.fill", colorHex: "E67E22"),
            Entry(id: UUID(), title: "Benzina", amount: Decimal(string: "62.00")!, date: .now.addingTimeInterval(-90000), symbolName: "fuelpump.fill", colorHex: "2E86DE"),
        ],
        topCategories: [
            CategorySlice(id: UUID(), name: "Spesa", amount: Decimal(string: "310.50")!, symbolName: "cart.fill", colorHex: "27AE60"),
            CategorySlice(id: UUID(), name: "Trasporti", amount: Decimal(string: "182.00")!, symbolName: "car.fill", colorHex: "2E86DE"),
            CategorySlice(id: UUID(), name: "Casa", amount: Decimal(string: "140.85")!, symbolName: "house.fill", colorHex: "8E44AD"),
        ],
        pendingSyncCount: 0,
        vaultConnected: true,
        generatedAt: .now
    )

    var budgetProgress: Double? {
        guard let monthlyBudget, monthlyBudget > 0 else { return nil }
        let spent = NSDecimalNumber(decimal: monthTotal).doubleValue
        let budget = NSDecimalNumber(decimal: monthlyBudget).doubleValue
        return min(max(spent / budget, 0), 1)
    }

    var budgetRemaining: Decimal? {
        guard let monthlyBudget else { return nil }
        return monthlyBudget - monthTotal
    }
}

/// Reads and writes the snapshot file in the shared container.
enum WidgetSnapshotStore {
    static let fileName = "widget-snapshot.json"

    private static var fileURL: URL? {
        AppGroup.containerURL?.appendingPathComponent(fileName, conformingTo: .json)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let fileURL else { return }
        do {
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // A failed widget refresh must never affect the app itself.
            print("[Soldo] Unable to write widget snapshot: \(error)")
        }
    }

    static func read() -> WidgetSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }
}
