import AppIntents
import Foundation
import SwiftData

/// A category, as Shortcuts sees it.
struct CategoryEntity: AppEntity, Identifiable {
    var id: UUID
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Categoria" }
    static var defaultQuery = CategoryEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct CategoryEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [CategoryEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [CategoryEntity] {
        let context = ScheiModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<SpendingCategory>(sortBy: [SortDescriptor(\.sortIndex)])
        let categories = (try? context.fetch(descriptor)) ?? []
        return categories.filter { !$0.isArchived }.map { CategoryEntity(id: $0.id, name: $0.name) }
    }
}

extension CategoryEntityQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [CategoryEntity] {
        try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}

/// A payment account, as Shortcuts sees it.
struct AccountEntity: AppEntity, Identifiable {
    var id: UUID
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Conto" }
    static var defaultQuery = AccountEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct AccountEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [AccountEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    @MainActor
    func suggestedEntities() async throws -> [AccountEntity] {
        let context = ScheiModelContainer.shared.mainContext
        let descriptor = FetchDescriptor<PaymentAccount>(sortBy: [SortDescriptor(\.sortIndex)])
        let accounts = (try? context.fetch(descriptor)) ?? []
        return accounts.filter { !$0.isArchived }.map { AccountEntity(id: $0.id, name: $0.name) }
    }
}

extension AccountEntityQuery: EntityStringQuery {
    @MainActor
    func entities(matching string: String) async throws -> [AccountEntity] {
        try await suggestedEntities().filter { $0.name.localizedCaseInsensitiveContains(string) }
    }
}

/// Periods offered by the "totale speso" action.
enum PeriodAppEnum: String, AppEnum {
    case today, week, month, year, all

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Periodo" }

    static var caseDisplayRepresentations: [PeriodAppEnum: DisplayRepresentation] = [
        .today: "Oggi",
        .week: "Questa settimana",
        .month: "Questo mese",
        .year: "Quest'anno",
        .all: "Sempre",
    ]

    var period: SpendingPeriod {
        switch self {
        case .today: .today
        case .week: .week
        case .month: .month
        case .year: .year
        case .all: .all
        }
    }
}
