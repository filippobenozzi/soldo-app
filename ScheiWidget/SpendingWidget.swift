import SwiftUI
import WidgetKit

struct SpendingWidget: Widget {
    // Unchanged across the rename: WidgetKit tracks placed widgets by kind.
    let kind = "SoldoSpendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            SpendingWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Spese del mese")
        .description("Quanto hai speso questo mese, con il budget se lo hai impostato.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct SpendingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var accent: Color { .primary }
    private var danger: Color { Color(uiColor: .systemRed) }

    var body: some View {
        content
            // Applied here so the Lock Screen families deep-link too, not just the
            // Home Screen ones.
            .widgetURL(URL(string: "soldo://add"))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryInline:
            Text("\(Money.compactString(snapshot.monthTotal, currencyCode: snapshot.currencyCode)) questo mese")

        case .accessoryCircular:
            ZStack {
                if let progress = snapshot.budgetProgress {
                    Gauge(value: progress) {
                        Image(systemName: "eurosign")
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                } else {
                    VStack(spacing: 0) {
                        Image(systemName: "eurosign.circle")
                            .font(.caption2)
                        Text(Money.compactString(snapshot.monthTotal, currencyCode: snapshot.currencyCode))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                    }
                }
            }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Questo mese")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(Money.string(snapshot.monthTotal, currencyCode: snapshot.currencyCode))
                    .font(.headline)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                if let remaining = snapshot.budgetRemaining {
                    Text(remaining >= 0
                         ? "Restano \(Money.compactString(remaining, currencyCode: snapshot.currencyCode))"
                         : "Sforato di \(Money.compactString(-remaining, currencyCode: snapshot.currencyCode))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

        case .systemMedium:
            mediumView

        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "eurosign.circle.fill")
                    .foregroundStyle(accent)
                Spacer()
                if let progress = snapshot.budgetProgress {
                    Text("\(Int((progress * 100).rounded()))%")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(progress > 1 ? danger : .secondary)
                }
            }

            Spacer(minLength: 0)

            Text("Questo mese")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(Money.compactString(snapshot.monthTotal, currencyCode: snapshot.currencyCode))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            if let progress = snapshot.budgetProgress {
                ProgressView(value: progress)
                    .tint(progress > 1 ? danger : accent)
            } else {
                Text("Oggi \(Money.compactString(snapshot.todayTotal, currencyCode: snapshot.currencyCode))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Questo mese")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(Money.compactString(snapshot.monthTotal, currencyCode: snapshot.currencyCode))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)

                if let remaining = snapshot.budgetRemaining {
                    Text(remaining >= 0
                         ? "Restano \(Money.compactString(remaining, currencyCode: snapshot.currencyCode))"
                         : "Sforato di \(Money.compactString(-remaining, currencyCode: snapshot.currencyCode))")
                        .font(.caption2)
                        .foregroundStyle(remaining >= 0 ? .secondary : danger)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    miniStat("Oggi", snapshot.todayTotal)
                    miniStat("7 gg", snapshot.weekTotal)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if snapshot.topCategories.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "chart.pie")
                        .font(.title)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(snapshot.topCategories.prefix(3)) { slice in
                        HStack(spacing: 6) {
                            Image(systemName: slice.symbolName)
                                .font(.caption2)
                                .foregroundStyle(InkPalette.tint(slice.colorHex, colorful: snapshot.isColorful))
                                .frame(width: 14)
                            Text(slice.name)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer(minLength: 2)
                            Text(Money.compactString(slice.amount, currencyCode: snapshot.currencyCode))
                                .font(.system(.caption2, design: .rounded, weight: .semibold))
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func miniStat(_ title: String, _ value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            Text(Money.compactString(value, currencyCode: snapshot.currencyCode))
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .lineLimit(1)
        }
    }
}
