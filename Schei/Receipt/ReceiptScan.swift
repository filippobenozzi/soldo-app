import Foundation

/// What Schei managed to read off a receipt.
struct ReceiptScan: Equatable {
    var merchant: String?
    var total: Decimal?
    var date: Date?
    var street: String?
    var locality: String?
    var vatNumber: String?
    var lines: [String] = []
    /// Every money-looking figure on the receipt, largest first — what the review
    /// sheet offers when the automatic pick is wrong.
    var candidateAmounts: [Decimal] = []

    var isEmpty: Bool {
        merchant == nil && total == nil && date == nil
    }

    /// The query handed to Maps to turn the receipt into a place.
    var placeQuery: String? {
        guard let merchant, !merchant.isEmpty else { return nil }
        return [merchant, street, locality]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
