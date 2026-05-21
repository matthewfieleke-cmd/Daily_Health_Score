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
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()
                ScrollView {
                    if let stats {
                        VStack(spacing: AppTheme.Layout.sectionSpacing) {
                            header(for: stats)
                            statsGrid(stats)
                            dailyList(stats)
                        }
                        .padding()
                    } else {
                        emptyState
                            .padding(.top, 60)
                            .padding(.horizontal)
                    }
                }
            }
            .navigationTitle(title)
        }
    }

    // MARK: - Header

    private func header(for stats: RollingStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Average score")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .textCase(.uppercase)
                        .tracking(1)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(ScoreCalculator.formatDisplayScore(stats.avgTotalScore))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text("/ 10")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0, min(stats.avgTotalScore / 10, 1))))
                        .stroke(AppTheme.leaf, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 56, height: 56)
            }
            Text("Based on \(stats.daysWithData) of the last \(stats.daysInWindow) days.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppTheme.heroGradient
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.heroCornerRadius, style: .continuous))
        )
        .shadow(color: AppTheme.backgroundDeep.opacity(0.22), radius: 12, x: 0, y: 6)
    }

    // MARK: - Stat tiles

    private func statsGrid(_ stats: RollingStats) -> some View {
        let items: [StatTile] = [
            StatTile(label: "Sleep",    value: "\(ScoreCalculator.formatDisplayScore(stats.avgSleepHours)) hr",
                     sub: "\(ScoreCalculator.formatDisplayScore(stats.avgSleepScore)) / 4",
                     icon: "moon.stars.fill", tint: AppTheme.primary),
            StatTile(label: "Fiber",    value: "\(ScoreCalculator.formatDisplayScore(stats.avgFiberGrams)) g",
                     sub: "\(ScoreCalculator.formatDisplayScore(stats.avgFiberScore)) / 4",
                     icon: "leaf.fill", tint: AppTheme.leaf),
            StatTile(label: "Exercise", value: "\(Int(stats.avgExerciseMinutes.rounded())) min",
                     sub: "\(ScoreCalculator.formatDisplayScore(stats.avgExerciseScore)) / 2",
                     icon: "figure.run", tint: AppTheme.tint(for: .exercise)),
        ]
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(items) { tile in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: tile.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tile.tint)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(tile.tint.opacity(0.15)))
                        Text(tile.label.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .tracking(0.5)
                    }
                    Text(tile.value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text(tile.sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .dhsCard()
            }
        }
    }

    private struct StatTile: Identifiable {
        let label: String
        let value: String
        let sub: String
        let icon: String
        let tint: Color
        var id: String { label }
    }

    // MARK: - Daily list

    private func dailyList(_ stats: RollingStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily breakdown")
                .font(.headline)
                .foregroundStyle(.primary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(stats.recordsInWindow) { record in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DateHelpers.formatDisplayDate(record.date))
                                .font(.subheadline.weight(.semibold))
                            Text(metricLine(for: record))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        scoreChip(record.totalScore)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    if record.id != stats.recordsInWindow.last?.id {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(AppTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
            .cardShadow()
        }
    }

    private func metricLine(for record: DailyRecord) -> String {
        let sleep = ScoreCalculator.formatDisplayScore(record.sleepHours)
        let fiber = ScoreCalculator.formatDisplayScore(record.fiberGrams)
        let exercise = Int(record.exerciseMinutes.rounded())
        return "Sleep \(sleep)h · Fiber \(fiber)g · Exercise \(exercise) min"
    }

    private func scoreChip(_ score: Double) -> some View {
        let fraction = max(0, min(score / 10, 1))
        let tint: Color = fraction >= 0.85 ? AppTheme.leaf
                        : fraction >= 0.6  ? AppTheme.primary
                        : Color.orange
        return Text(ScoreCalculator.formatDisplayScore(score))
            .font(.subheadline.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tint.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Empty

    private var emptyState: some View {
        ContentUnavailableView(
            "No records",
            systemImage: "calendar",
            description: Text("No records in the last \(days) days yet.")
        )
    }
}
