import SwiftUI

struct RollingSummaryView: View {
    @EnvironmentObject private var appState: AppState
    let days: Int
    let title: String
    @State private var coachFocus: CoachFocusContext?
    @State private var foodLogDate = ""
    @State private var showFoodLog = false

    private var stats: RollingStats? {
        let settings = appState.settingsStore.settings
        let filled = CompletedTrendBuilder.filledRecords(
            days: days,
            records: appState.recordStore.records,
            settings: settings
        )
        guard !filled.isEmpty else { return nil }
        return RollingStatsCalculator.compute(
            records: filled,
            windowKeys: filled.map(\.date),
            nutritionMode: settings.nutritionMode,
            movementGoal: settings.movementGoal
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
                            AskCoachButton {
                                let keys = stats.recordsInWindow.map(\.date).sorted()
                                coachFocus = CoachFocusContextBuilder.history(
                                    stats: stats,
                                    days: days,
                                    windowKeys: keys,
                                    nutritionMode: appState.settingsStore.settings.nutritionMode
                                )
                            }
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
            .enlargedAppNavigationBar(title: title)
        }
        .sheet(isPresented: $showFoodLog) {
            FoodGroupLogSheet(dateKey: foodLogDate)
                .environmentObject(appState)
        }
        .sheet(item: $coachFocus) { focus in
            NavigationStack {
                LifestyleCoachChatView(focus: focus)
                    .environmentObject(appState)
                    .environmentObject(appState.coach)
            }
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
            Text(completedCaption(for: stats))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
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
            nutritionTile(stats),
            StatTile(
                label: selectedMovementGoal.metricName,
                value: "\(MovementGoal.formatCount(stats.avgMovementValue)) \(selectedMovementGoal.unit)",
                sub: "\(ScoreCalculator.formatDisplayScore(stats.avgExerciseScore)) / 2",
                icon: selectedMovementGoal.systemImage,
                tint: AppTheme.tint(for: PrimaryFocus.exercise)
            ),
        ]
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(items) { tile in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: tile.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(tile.tint)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(tile.tint.opacity(0.15)))
                        ZStack(alignment: .topLeading) {
                            Text("EXERCISE\nMINUTES")
                                .font(.caption2.weight(.semibold))
                                .lineLimit(2)
                                .hidden()
                                .accessibilityHidden(true)
                            Text(tile.label.uppercased())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    Text(tile.value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(tile.sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
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
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        Spacer()
                        scoreChip(record.totalScore)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture { openDay(record) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint(dayHint)
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

    private func completedCaption(for stats: RollingStats) -> String {
        let oldest = stats.recordsInWindow.last?.date
        let newest = stats.recordsInWindow.first?.date
        let range: String
        if let oldest, let newest, oldest != newest {
            range = "\(shortDay(oldest))–\(shortDay(newest)). "
        } else if let newest {
            range = "\(shortDay(newest)). "
        } else {
            range = ""
        }
        let progress = "Today is still in progress and is not included. "
        if stats.daysInWindow < days {
            let noun = stats.daysInWindow == 1 ? "day" : "days"
            return "\(range)\(stats.daysInWindow) completed \(noun) so far. \(progress)Days with nothing logged count as zero."
        }
        return "\(range)\(progress)Days with nothing logged count as zero."
    }

    private func shortDay(_ key: String) -> String {
        guard let date = DateHelpers.date(from: key) else { return key }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var selectedMovementGoal: MovementGoal {
        appState.settingsStore.settings.movementGoal
    }

    private var nutritionMode: NutritionMode {
        appState.settingsStore.settings.nutritionMode
    }

    private var dayHint: String {
        nutritionMode == .foodGroups ? "Opens this day's food log" : "Ask Coach about this day"
    }

    private func nutritionTile(_ stats: RollingStats) -> StatTile {
        if nutritionMode == .foodGroups {
            return StatTile(
                label: "Food groups",
                value: ScoreCalculator.formatDisplayScore(stats.avgFiberScore),
                sub: "\(ScoreCalculator.formatDisplayScore(stats.avgFiberScore)) / 4",
                icon: "fork.knife",
                tint: AppTheme.leaf
            )
        }
        return StatTile(
            label: "Fiber",
            value: "\(ScoreCalculator.formatDisplayScore(stats.avgFiberGrams)) g",
            sub: "\(ScoreCalculator.formatDisplayScore(stats.avgFiberScore)) / 4",
            icon: "leaf.fill",
            tint: AppTheme.leaf
        )
    }

    private func openDay(_ record: DailyRecord) {
        if nutritionMode == .foodGroups {
            foodLogDate = record.date
            showFoodLog = true
        } else {
            coachFocus = CoachFocusContextBuilder.day(
                record,
                dateKey: record.date,
                nutritionMode: nutritionMode
            )
        }
    }

    private func metricLine(for record: DailyRecord) -> String {
        let sleep = ScoreCalculator.formatDisplayScore(record.sleepHours)
        let goal = appState.settingsStore.settings.movementGoal
        let movementValue = goal.countsSteps ? record.stepCount : record.exerciseMinutes
        let movement = "\(MovementGoal.formatCount(movementValue)) \(goal.unit)"
        let nutrition: String
        if nutritionMode == .foodGroups {
            let score = FoodGroupScore.points(record.foodGroups)
            nutrition = "Food groups \(ScoreCalculator.formatDisplayScore(score))"
        } else {
            nutrition = "Fiber \(ScoreCalculator.formatDisplayScore(record.fiberGrams))g"
        }
        return "Sleep \(sleep)h · \(nutrition) · \(movement)"
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
            "No completed days yet",
            systemImage: "calendar",
            description: Text("Today is still in progress. Finished days will show here tomorrow.")
        )
    }
}
