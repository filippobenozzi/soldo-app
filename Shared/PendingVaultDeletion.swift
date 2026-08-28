import Foundation
import SwiftData

/// Remembers an expense that was deleted in Schei so the next sync run can also
/// remove it from the vault. Rows are dropped once the vault has been cleaned.
@Model
final class PendingVaultDeletion {
    var id: UUID = UUID()
    var expenseID: UUID = UUID()
    var relativePath: String?
    var expenseDate: Date = Date.now
    var createdAt: Date = Date.now

    init(expenseID: UUID, relativePath: String?, expenseDate: Date) {
        self.id = UUID()
        self.expenseID = expenseID
        self.relativePath = relativePath
        self.expenseDate = expenseDate
        self.createdAt = .now
    }
}
