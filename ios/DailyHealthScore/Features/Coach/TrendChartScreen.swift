import SwiftUI

/// Full finished-day chart. Close returns to the screen that opened it.
/// Sleep, fiber, and movement share one screen so the person can switch
/// without starting over. The 30- and 90-day lines are labels, not buttons.
struct TrendChartScreen: View {
    @Environment(\.dismiss) private var dismiss

    let records: [DailyRecord]
    let settings: UserSettings
    var showsTalk: Bool
    var onTalk: (() -> Void)?
    /// Keeps a chart that was already drawn from flipping units if the goal changes later.
    var lockedReference: TrendChartReference?

    @State private var metric: TrendMetric

    init(
        records: [DailyRecord],
        settings: UserSettings,
        metric: TrendMetric,
        showsTalk: Bool = false,
        onTalk: (() -> Void)? = nil,
        lockedReference: TrendChartReference? = nil
    ) {
        self.records = records
        self.settings = settings
        self.showsTalk = showsTalk
        self.onTalk = onTalk
        self.lockedReference = lockedReference
        _metric = State(initialValue: metric)
    }

    private var displaySettings: UserSettings {
        guard let lockedReference else { return settings }
        var resolved = settings
        if let goal = MovementGoal(rawValue: lockedReference.movementGoalRaw), !lockedReference.movementGoalRaw.isEmpty {
            resolved.movementGoal = goal
        }
        if metric == .fiber {
            if !lockedReference.nutritionModeRaw.isEmpty {
                resolved.nutritionMode = NutritionMode(rawValue: lockedReference.nutritionModeRaw) ?? .fiber
            } else if lockedReference.metric == .fiber {
                resolved.nutritionMode = .fiber
            }
        }
        return resolved
    }

    private var trend: CompletedTrend? {
        CompletedTrendBuilder.build(metric: metric, records: records, settings: displaySettings)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Metric", selection: $metric) {
                    Text("Sleep").tag(TrendMetric.sleep)
                    Text(displaySettings.nutritionMode.cardTitle).tag(TrendMetric.fiber)
                    Text(displaySettings.movementGoal.metricName).tag(TrendMetric.movement)
                }
                .pickerStyle(.segmented)

                if let trend {
                    TrendChartCard(trend: trend)
                } else {
                    ContentUnavailableView(
                        "No completed days yet",
                        systemImage: "chart.bar",
                        description: Text("Today is still in progress. Finished days will appear here tomorrow.")
                    )
                }
            }
            .padding(20)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Completed days")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            if showsTalk, let onTalk {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Talk about this", action: onTalk)
                }
            }
        }
    }
}
