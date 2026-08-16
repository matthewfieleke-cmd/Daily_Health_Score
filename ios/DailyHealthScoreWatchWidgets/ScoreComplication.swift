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
        let snapshot = WatchSnapshotStore.load()
        let entry = ScoreEntry(date: Date(), snapshot: snapshot)
        let retry = snapshot == nil ? 60.0 : 15 * 60.0
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(retry))))
    }
}

struct ScoreComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WatchBridge.scoreComplicationKind, provider: ScoreProvider()) { entry in
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
    private var placeholder: Bool { entry.snapshot == nil }
    private var label: String {
        placeholder ? "--" : String(format: "%.1f", (score * 10).rounded() / 10)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                WatchScoreRing(score: score, placeholder: placeholder)
                    .padding(1)
            case .accessoryCorner:
                WatchScoreRing(score: score, placeholder: placeholder)
                    .widgetLabel {
                        Text(label)
                            .monospacedDigit()
                    }
            case .accessoryRectangular:
                HStack(spacing: 8) {
                    WatchScoreRing(score: score, placeholder: placeholder)
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.headline.monospacedDigit())
                        if let snapshot = entry.snapshot {
                            Text("S \(snapshot.sleep.formattedValue)  F \(snapshot.fiber.formattedValue)  E \(snapshot.exercise.formattedValue)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            case .accessoryInline:
                Text("DHS \(label)")
            default:
                WatchScoreRing(score: score, placeholder: placeholder)
            }
        }
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
        .accessibilityLabel("Daily score")
        .accessibilityValue(placeholder ? "No score yet" : "\(label) out of ten")
    }
}
