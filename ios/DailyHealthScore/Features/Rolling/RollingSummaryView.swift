import SwiftUI

struct RollingSummaryView: View {
    @EnvironmentObject private var appState: AppState
    let days: Int
    let title: String

    private var stats: RollingStats? {
        let keys = DateHelpers.rollingDateKeys(days: days)
        return RollingStatsCalculator.compute(
            records: appState.recordStore.records,
            windowKeys: keys
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let stats {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Based on \(stats.daysWithData) of the last \(stats.daysInWindow) days.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        statsGrid(stats)

                        Text("Daily breakdown")
                            .font(.headline)

                        ForEach(stats.recordsInWindow) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(DateHelpers.formatDisplayDate(record.date))
                                    .font(.subheadline.weight(.semibold))
                                Text(
                                    "Score \(ScoreCalculator.formatDisplayScore(record.totalScore)) / 10 · " +
                                    "Sleep \(ScoreCalculator.formatDisplayScore(record.sleepHours)) hr · " +
                                    "Fiber \(ScoreCalculator.formatDisplayScore(record.fiberGrams)) g · " +
                                    "Exercise \(ScoreCalculator.formatDisplayScore(record.exerciseMinutes)) min"
                                )
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6)
                            Divider()
                        }
                    }
                    .padding()
                } else {
                    ContentUnavailableView(
                        "No records",
                        systemImage: "calendar",
                        description: Text("No records in the last \(days) days yet.")
                    )
                }
            }
            .navigationTitle(title)
        }
    }

    @ViewBuilder
    private func statsGrid(_ stats: RollingStats) -> some View {
        let items: [(String, String)] = [
            ("Average total score", "\(ScoreCalculator.formatDisplayScore(stats.avgTotalScore)) / 10"),
            ("Average sleep", "\(ScoreCalculator.formatDisplayScore(stats.avgSleepHours)) hr"),
            ("Average fiber", "\(ScoreCalculator.formatDisplayScore(stats.avgFiberGrams)) g"),
            ("Average exercise", "\(ScoreCalculator.formatDisplayScore(stats.avgExerciseMinutes)) min"),
            ("Avg sleep sub-score", "\(ScoreCalculator.formatDisplayScore(stats.avgSleepScore)) / 4"),
            ("Avg fiber sub-score", "\(ScoreCalculator.formatDisplayScore(stats.avgFiberScore)) / 4"),
            ("Avg exercise sub-score", "\(ScoreCalculator.formatDisplayScore(stats.avgExerciseScore)) / 2"),
        ]
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(items.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 4) {
                    Text(items[i].0.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(items[i].1)
                        .font(.subheadline.weight(.semibold))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}
