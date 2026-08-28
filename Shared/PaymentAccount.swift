import Foundation
import SwiftData

/// How an expense was paid: cash, card, a specific bank account…
@Model
final class PaymentAccount {
    var id: UUID = UUID()
    var name: String = ""
    var symbolName: String = "creditcard.fill"
    var colorHex: String = "2E86DE"
    var sortIndex: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \Expense.account)
    var expenses: [Expense]? = []

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String = "creditcard.fill",
        colorHex: String = "2E86DE",
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

    static let defaults: [(name: String, symbol: String, hex: String)] = [
        ("Carta", "creditcard.fill", "2E86DE"),
        ("Contanti", "banknote.fill", "27AE60"),
        ("Apple Pay", "wallet.pass.fill", "596275"),
    ]
}
