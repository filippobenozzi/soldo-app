import Foundation

/// Date ranges used across Home, Insights and the widget.
enum SpendingPeriod: String, CaseIterable, Identifiable {
    case today, week, month, year, all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: "Oggi"
        case .week: "Settimana"
        case .month: "Mese"
        case .year: "Anno"
        case .all: "Sempre"
        }
    }

    var shortLabel: String {
        switch self {
        case .today: "Oggi"
        case .week: "7 gg"
        case .month: "Mese"
        case .year: "Anno"
        case .all: "Tutto"
        }
    }

    /// `nil` for `.all`, which has no bounds.
    func interval(containing date: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .today: calendar.dateInterval(of: .day, for: date)
        case .week: calendar.dateInterval(of: .weekOfYear, for: date)
        case .month: calendar.dateInterval(of: .month, for: date)
        case .year: calendar.dateInterval(of: .year, for: date)
        case .all: nil
        }
    }

    func contains(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let interval = interval(containing: now, calendar: calendar) else { return true }
        return interval.contains(date)
    }
}

/// Aggregations computed in memory — expense counts stay small enough that a
/// fetch-then-reduce is simpler and safer than pushing sums into SwiftData.
enum SpendingSummary {
    static func total(_ expenses: [Expense]) -> Decimal {
        expenses.reduce(Decimal.zero) { $0 + $1.amount }
    }

    static func total(_ expenses: [Expense], in period: SpendingPeriod, now: Date = .now) -> Decimal {
        total(expenses.filter { period.contains($0.date, now: now) })
    }

    struct CategoryTotal: Identifiable, Equatable {
        var id: UUID
        var name: String
        var symbolName: String
        var colorHex: String
        var amount: Decimal
        var count: Int
    }

    static func byCategory(_ expenses: [Expense]) -> [CategoryTotal] {
        var buckets: [UUID: CategoryTotal] = [:]
        let uncategorizedID = UUID(uuidString: "00000000-0000-0000-0000-0000000000FF")!

        for expense in expenses {
            let category = expense.category
            let key = category?.id ?? uncategorizedID
            if var existing = buckets[key] {
                existing.amount += expense.amount
                existing.count += 1
                buckets[key] = existing
            } else {
                buckets[key] = CategoryTotal(
                    id: key,
                    name: category?.name ?? "Senza categoria",
                    symbolName: category?.symbolName ?? "questionmark.circle.fill",
                    colorHex: category?.colorHex ?? "596275",
                    amount: expense.amount,
                    count: 1
                )
            }
        }

        return buckets.values.sorted { $0.amount > $1.amount }
    }

    struct DayTotal: Identifiable, Equatable {
        var id: Date { date }
        var date: Date
        var amount: Decimal
    }

    /// One bucket per day in `interval`, including days with no spending so charts
    /// don't collapse gaps.
    static func byDay(_ expenses: [Expense], in interval: DateInterval, calendar: Calendar = .current) -> [DayTotal] {
        var buckets: [Date: Decimal] = [:]
        var cursor = calendar.startOfDay(for: interval.start)
        let end = interval.end

        while cursor < end {
            buckets[cursor] = 0
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        for expense in expenses where interval.contains(expense.date) {
            let day = calendar.startOfDay(for: expense.date)
            buckets[day, default: 0] += expense.amount
        }

        return buckets
            .map { DayTotal(date: $0.key, amount: $0.value) }
            .sorted { $0.date < $1.date }
    }

    struct MonthTotal: Identifiable, Equatable {
        var id: Date { month }
        var month: Date
        var amount: Decimal
    }

    static func byMonth(_ expenses: [Expense], lastMonths: Int = 12, now: Date = .now, calendar: Calendar = .current) -> [MonthTotal] {
        guard let currentMonth = calendar.dateInterval(of: .month, for: now)?.start else { return [] }

        var buckets: [Date: Decimal] = [:]
        for offset in stride(from: -(lastMonths - 1), through: 0, by: 1) {
            if let month = calendar.date(byAdding: .month, value: offset, to: currentMonth) {
                buckets[month] = 0
            }
        }

        for expense in expenses {
            guard let month = calendar.dateInterval(of: .month, for: expense.date)?.start,
                  buckets[month] != nil else { continue }
            buckets[month, default: 0] += expense.amount
        }

        return buckets
            .map { MonthTotal(month: $0.key, amount: $0.value) }
            .sorted { $0.month < $1.month }
    }

    /// Average per day over the elapsed part of the current month.
    static func dailyAverageThisMonth(_ expenses: [Expense], now: Date = .now, calendar: Calendar = .current) -> Decimal {
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return 0 }
        let elapsedDays = max(calendar.dateComponents([.day], from: interval.start, to: now).day ?? 0, 0) + 1
        let monthTotal = total(expenses.filter { interval.contains($0.date) })
        return monthTotal / Decimal(elapsedDays)
    }

    /// Projection for the full month at the current pace.
    static func projectedMonthTotal(_ expenses: [Expense], now: Date = .now, calendar: Calendar = .current) -> Decimal {
        guard let interval = calendar.dateInterval(of: .month, for: now),
              let daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count
        else { return 0 }
        _ = interval
        return dailyAverageThisMonth(expenses, now: now, calendar: calendar) * Decimal(daysInMonth)
    }
}
