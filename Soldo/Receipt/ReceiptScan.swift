import Foundation

/// What Soldo managed to read off a receipt.
struct ReceiptScan: Equatable {
    var merchant: String?
    var total: Decimal?
    var date: Date?
    var street: String?
    var locality: String?
    var vatNumber: String?
    var lines: [String] = []

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
