import Foundation
import SwiftData

@Model
final class SpendingCategory {
    var id: UUID = UUID()
    var name: String = ""
    var symbolName: String = "tag.fill"
    var colorHex: String = "27AE60"
    var sortIndex: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Expense.category)
    var expenses: [Expense]? = []

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "tag.fill",
        colorHex: String = "27AE60",
        sortIndex: Int = 0,
        isArchived: Bool = false
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortIndex = sortIndex
        self.isArchived = isArchived
        self.createdAt = .now
    }

    /// Categories created on first launch. Kept in Italian to match the app's UI.
    static let defaults: [(name: String, symbol: String, hex: String)] = [
        ("Spesa", "cart.fill", "27AE60"),
        ("Ristoranti", "fork.knife", "E67E22"),
        ("Trasporti", "car.fill", "2E86DE"),
        ("Casa", "house.fill", "8E44AD"),
        ("Bollette", "bolt.fill", "F39C12"),
        ("Salute", "cross.case.fill", "C0392B"),
        ("Svago", "gamecontroller.fill", "E84393"),
        ("Shopping", "bag.fill", "5F6CAF"),
        ("Viaggi", "airplane", "0FB9B1"),
        ("Abbonamenti", "arrow.triangle.2.circlepath", "16A085"),
        ("Altro", "ellipsis.circle.fill", "596275"),
    ]
}
