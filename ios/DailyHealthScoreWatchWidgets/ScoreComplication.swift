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
        ScoreEntry(date: Date(), snapshot: Self.loadStoredSnapshot(at: Date()))
    }

    func getSnapshot(in context: Context, completion: @escaping (ScoreEntry) -> Void) {
        Self.loadBestSnapshot(timeout: 1.0) { snapshot in
            completion(ScoreEntry(date: Date(), snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ScoreEntry>) -> Void) {
        Self.loadBestSnapshot(timeout: 1.5) { snapshot in
            let now = Date()
            var entries = [ScoreEntry(date: now, snapshot: snapshot)]
            let calendar = Calendar.current
            let midnight = calendar.nextDate(
                after: now,
                matching: DateComponents(hour: 0, minute: 0, second: 0),
                matchingPolicy: .nextTime
            )
            if let midnight {
                entries.append(ScoreEntry(date: midnight, snapshot: nil))
            }
            let reloadAfter = WatchComplicationTimeline.reloadDate(now: now, midnight: midnight)
            completion(Timeline(entries: entries, policy: .after(reloadAfter)))
        }
    }

    /// App Group first (Watch app persist), then the same WCSession context
    /// the Watch app already shows, then HealthKit. The face used to stay on
    /// Open iPhone whenever the group container was nil.
    static func loadStoredSnapshot(at now: Date) -> WatchSnapshot? {
        WatchSnapshot.preferredForFace(WatchSnapshotStore.load(), at: now)
    }

    static func loadBestSnapshot(
        timeout: TimeInterval,
        completion: @escaping (WatchSnapshot?) -> Void
    ) {
        let now = Date()
        if let stored = loadStoredSnapshot(at: now) {
            completion(stored)
            return
        }
        WatchFaceSessionReader.fetch(timeout: timeout) { sessionSnapshot in
            if let sessionSnapshot {
                completion(WatchSnapshot.preferredForFace(sessionSnapshot, at: now) ?? sessionSnapshot)
                return
            }
            Task {
                let health = await WatchFaceHealthSnapshot.loadToday(at: now)
                completion(health)
            }
        }
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

    private var score: Double { liveSnapshot?.totalScore ?? 0 }
    private var placeholder: Bool { liveSnapshot == nil }
    private var liveSnapshot: WatchSnapshot? {
        WatchSnapshot.preferredForFace(entry.snapshot, WatchSnapshotStore.load(), at: Date())
    }
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
        .unredacted()
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
                if let snapshot = liveSnapshot {
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
    }

    private var accessibilityValue: String {
        guard let snapshot = liveSnapshot else { return "No score yet" }
        if family == .accessoryRectangular {
            return "\(label) out of ten. \(snapshot.rectangularAccessibilityLine)"
        }
        return "\(label) out of ten"
    }
}
