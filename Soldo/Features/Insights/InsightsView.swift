import Charts
import SwiftData
import SwiftUI

struct InsightsView: View {
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]

    @State private var period: SpendingPeriod = .month

    private var scoped: [Expense] {
        expenses.filter { period.contains($0.date) }
    }

    private var total: Decimal { SpendingSummary.total(scoped) }

    /// Same-length window immediately before the current one, for the trend pill.
    private var previousTotal: Decimal? {
        guard let interval = period.interval() else { return nil }
        let length = interval.duration
        let previous = DateInterval(start: interval.start.addingTimeInterval(-length), duration: length)
        return SpendingSummary.total(expenses.filter { previous.contains($0.date) })
    }

    private var categoryTotals: [SpendingSummary.CategoryTotal] {
        SpendingSummary.byCategory(scoped)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Periodo", selection: $period) {
                        ForEach(SpendingPeriod.allCases) { period in
                            Text(period.shortLabel).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)

                    totalCard

                    if scoped.isEmpty {
                        EmptyStateView(
                            symbol: "chart.bar.xaxis",
                            title: "Niente da analizzare",
                            message: "Registra qualche spesa e qui compariranno i grafici."
                        )
                        .soldoCard()
                    } else {
                        trendCard
                        categoryCard
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(SoldoTheme.groupedBackground)
            .navigationTitle("Analisi")
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Totale \(period.label.lowercased())")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(Money.string(total, currencyCode: settings.currencyCode))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack(spacing: 14) {
                if let previousTotal, previousTotal > 0 {
                    let delta = total - previousTotal
                    let ratio = NSDecimalNumber(decimal: delta / previousTotal).doubleValue
                    Label(
                        "\(delta >= 0 ? "+" : "")\(Int((ratio * 100).rounded()))% vs periodo precedente",
                        systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(delta >= 0 ? SoldoTheme.danger : .secondary)
                }
                Text("\(scoped.count) \(scoped.count == 1 ? "spesa" : "spese")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if period == .month {
                Divider().padding(.vertical, 2)
                HStack {
                    Text("Proiezione fine mese")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Money.string(SpendingSummary.projectedMonthTotal(expenses), currencyCode: settings.currencyCode))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                }
            }
        }
        .soldoCard()
    }

    @ViewBuilder
    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(period == .year || period == .all ? "Andamento mensile" : "Andamento giornaliero")
                .font(.headline)

            if period == .year || period == .all {
                let months = SpendingSummary.byMonth(expenses, lastMonths: 12)
                Chart(months) { item in
                    BarMark(
                        x: .value("Mese", item.month, unit: .month),
                        y: .value("Totale", NSDecimalNumber(decimal: item.amount).doubleValue)
                    )
                    .foregroundStyle(SoldoTheme.ink)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 2)) { value in
                        AxisValueLabel(format: .dateTime.month(.narrow))
                    }
                }
                .frame(height: 180)
            } else if let interval = period.interval() {
                let days = SpendingSummary.byDay(scoped, in: interval)
                Chart(days) { item in
                    BarMark(
                        x: .value("Giorno", item.date, unit: .day),
                        y: .value("Totale", NSDecimalNumber(decimal: item.amount).doubleValue)
                    )
                    .foregroundStyle(SoldoTheme.ink)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .frame(height: 180)
            }
        }
        .soldoCard()
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Per categoria")
                .font(.headline)

            Chart(Array(categoryTotals.enumerated()), id: \.element.id) { index, item in
                SectorMark(
                    angle: .value("Totale", NSDecimalNumber(decimal: item.amount).doubleValue),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .foregroundStyle(SoldoTheme.chartTint(item.colorHex, index: index, count: categoryTotals.count))
                .cornerRadius(4)
            }
            .frame(height: 190)

            VStack(spacing: 0) {
                ForEach(Array(categoryTotals.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        SymbolBadge(symbolName: item.symbolName, colorHex: item.colorHex, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.subheadline.weight(.medium))
                            Text("\(item.count) \(item.count == 1 ? "spesa" : "spese") · \(percentage(item.amount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(Money.string(item.amount, currencyCode: settings.currencyCode))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .padding(.vertical, 8)

                    if index < categoryTotals.count - 1 {
                        Divider().padding(.leading, 42)
                    }
                }
            }
        }
        .soldoCard()
    }

    private func percentage(_ amount: Decimal) -> String {
        guard total > 0 else { return "0%" }
        let ratio = NSDecimalNumber(decimal: amount / total).doubleValue
        return "\(Int((ratio * 100).rounded()))%"
    }
}
