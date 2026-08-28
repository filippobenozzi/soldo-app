import SwiftUI
import WidgetKit

struct RecentExpensesWidget: Widget {
    // Unchanged across the rename: WidgetKit tracks placed widgets by kind.
    let kind = "SoldoRecentExpensesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { entry in
            RecentExpensesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Ultime spese")
        .description("Le spese registrate più di recente.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct RecentExpensesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var maxRows: Int { family == .systemLarge ? 7 : 3 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ultime spese")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(Money.compactString(snapshot.monthTotal, currencyCode: snapshot.currencyCode))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
            }

            if snapshot.recent.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Tocca per aggiungere")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(snapshot.recent.prefix(maxRows)) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.symbolName)
                            .font(.caption2)
                            .foregroundStyle(InkPalette.tint(item.colorHex, colorful: snapshot.isColorful))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.title)
                                .font(.caption)
                                .lineLimit(1)
                            Text(item.date, format: .dateTime.day().month(.abbreviated))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Text(Money.string(item.amount, currencyCode: snapshot.currencyCode))
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .widgetURL(URL(string: "soldo://add"))
    }
}
