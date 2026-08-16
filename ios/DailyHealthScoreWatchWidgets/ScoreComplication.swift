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
        .description("Today’s score, with sleep, fiber, and exercise in the expanded slot.")
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
                rectangularBody
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
        .accessibilityValue(accessibilityValue)
    }

    /// Modular's expanded slot is a Graphic Rectangular template: a capacity
    /// gauge plus header/body text. Custom GeometryReader rings steal the
    /// width and WidgetKit leaves the text slots as skeleton bars.
    private var rectangularBody: some View {
        HStack(alignment: .center, spacing: 6) {
            Gauge(value: placeholder ? 0 : min(max(score, 0), 10), in: 0...10) {
                Text("Score")
            } currentValueLabel: {
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(WatchBrand.ringColor(fraction: placeholder ? 0 : min(max(score / 10, 0), 1)))
            .frame(width: 36, height: 36)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("Today")
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                if let snapshot = entry.snapshot {
                    ViewThatFits(in: .horizontal) {
                        Text(snapshot.rectangularPillarLine)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(snapshot.rectangularPillarLineSleepFiber)
                                .lineLimit(1)
                            Text(snapshot.rectangularPillarLineExercise)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                } else {
                    Text("Open iPhone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .unredacted()
    }

    private var accessibilityValue: String {
        guard let snapshot = entry.snapshot else { return "No score yet" }
        if family == .accessoryRectangular {
            return "\(label) out of ten. \(snapshot.rectangularAccessibilityLine)"
        }
        return "\(label) out of ten"
    }
}
