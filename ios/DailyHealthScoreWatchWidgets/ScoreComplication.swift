import WidgetKit
import SwiftUI

@main
struct DailyHealthScoreWatchWidgets: WidgetBundle {
    var body: some Widget {
        ScoreComplication()
    }
}

struct ScoreEntry: TimelineEntry {
    let date: Date
    let snapshot: WatchSnapshot?
}

struct ScoreProvider: TimelineProvider {
    func placeholder(in context: Context) -> ScoreEntry {
        ScoreEntry(date: Date(), snapshot: WatchSnapshotStore.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (ScoreEntry) -> Void) {
        completion(ScoreEntry(date: Date(), snapshot: WatchSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScoreEntry>) -> Void) {
        let entry = ScoreEntry(date: Date(), snapshot: WatchSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60))))
    }
}

struct ScoreComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DHSScoreComplication", provider: ScoreProvider()) { entry in
            ScoreComplicationView(entry: entry)
        }
        .configurationDisplayName("Daily Health Score")
        .description("Today’s score as a filling ring.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct ScoreComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ScoreEntry

    private var score: Double { entry.snapshot?.totalScore ?? 0 }
    private var fraction: Double { max(0, min(score / 10, 1)) }
    private var label: String {
        entry.snapshot == nil ? "--" : String(format: "%.1f", (score * 10).rounded() / 10)
    }

    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryCorner:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            Text("DHS \(label)")
        default:
            circular
        }
    }

    private var circular: some View {
        Gauge(value: fraction) {
            Text(label)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(WatchBrand.ringColor(fraction: fraction))
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            Gauge(value: fraction) {
                Text(label)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(WatchBrand.ringColor(fraction: fraction))
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("DHS \(label)")
                    .font(.headline)
                if let snapshot = entry.snapshot {
                    Text("S \(snapshot.sleep.formattedValue)  F \(snapshot.fiber.formattedValue)  E \(snapshot.exercise.formattedValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
