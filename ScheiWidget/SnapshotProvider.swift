import WidgetKit

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// Reads the JSON the app writes into the App Group container. When that container
/// is unavailable — which happens with some sideloading setups — the widget shows
/// the placeholder instead of failing.
struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : (WidgetSnapshotStore.read() ?? .placeholder)
        completion(SnapshotEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.read() ?? .empty
        let entry = SnapshotEntry(date: .now, snapshot: snapshot)

        // The app reloads timelines on every change; this is only the safety net
        // that keeps "today" correct across midnight.
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}
