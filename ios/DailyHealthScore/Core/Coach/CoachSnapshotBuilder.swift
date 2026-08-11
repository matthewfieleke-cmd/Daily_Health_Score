import Foundation

enum CoachSnapshotBuilder {
    static func build(
        today: DailyRecord,
        records: [DailyRecord],
        goals: [SMARTGoal] = [],
        hrvSensitivity: HRVSensitivity = .balanced,
        phase: DayPhase = .current()
    ) -> CoachSnapshot {
        let weekKeys = DateHelpers.rollingDateKeys(days: 7)
        let weekStats = RollingStatsCalculator.compute(records: records, windowKeys: weekKeys)
        let weekRecords = weekStats?.recordsInWindow ?? []
        let fiberDays = weekRecords.filter { $0.fiberGrams > 0 }.count

        // HRV only enters the prompt once some nights exist; otherwise the coach
        // would discuss a metric the person is not collecting.
        let hrvSummary: String? = records.contains { $0.sleepHrvSDNNMs != nil }
            ? CoachHRVSummarizer.line(
                for: HRVBaselineAnalyzer.analyze(
                    records: records,
                    todayKey: today.date,
                    sensitivity: hrvSensitivity
                )
            )
            : nil

        return CoachSnapshot(
            todayKey: today.date,
            dayPhase: phase,
            totalScore: today.totalScore,
            sleep: status(
                name: "Sleep",
                value: today.sleepHours,
                goal: today.sleepGoal.rawValue,
                unit: "h",
                decimals: 1,
                points: today.sleepScore,
                maxPoints: 4
            ),
            fiber: status(
                name: "Fiber",
                value: today.fiberGrams,
                goal: Double(today.fiberGoal.rawValue),
                unit: "g",
                decimals: 1,
                points: today.fiberScore,
                maxPoints: 4
            ),
            exercise: status(
                name: "Exercise",
                value: today.exerciseMinutes,
                goal: Double(today.exerciseGoalMinutes),
                unit: "min",
                decimals: 0,
                points: today.exerciseScore,
                maxPoints: 2
            ),
            primaryFocus: today.primaryFocus,
            weekDaysWithData: weekStats?.daysWithData ?? 0,
            weekAvgScore: weekStats?.avgTotalScore,
            weekAvgSleep: weekStats?.avgSleepHours,
            weekAvgFiber: weekStats?.avgFiberGrams,
            weekAvgExercise: weekStats?.avgExerciseMinutes,
            fiberDaysLoggedInWeek: fiberDays,
            hrvSummary: hrvSummary,
            smartGoals: CoachGoalSummarizer.lines(for: goals)
        )
    }

    /// Computes the goal comparison in Swift so the model only has to phrase it.
    static func status(
        name: String,
        value: Double,
        goal: Double,
        unit: String,
        decimals: Int,
        points: Double,
        maxPoints: Double
    ) -> CoachMetricStatus {
        let level: CoachMetricLevel
        if value <= 0 {
            level = .missing
        } else if value >= goal * 1.05 {
            level = .exceeded
        } else if value >= goal {
            level = .met
        } else {
            level = .below
        }

        let valueText = format(value, decimals: decimals)
        let goalText = format(goal, decimals: goal.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)
        let percent = goal > 0 ? Int((value / goal * 100).rounded()) : 0
        let pointsText = String(format: "%.1f of %.0f points", points, maxPoints)

        let sentence: String
        switch level {
        case .missing:
            sentence = "\(name): no data logged today (goal \(goalText) \(unit)). Status: NO DATA — unlogged, not necessarily zero behavior. \(pointsText)."
        case .below:
            let gap = format(max(goal - value, 0), decimals: decimals)
            sentence = "\(name): \(valueText) \(unit) of a \(goalText) \(unit) goal — BELOW GOAL by \(gap) \(unit) (\(percent)% of goal). \(pointsText)."
        case .met:
            sentence = "\(name): \(valueText) \(unit) of a \(goalText) \(unit) goal — GOAL MET (\(percent)% of goal). \(pointsText)."
        case .exceeded:
            let over = format(max(value - goal, 0), decimals: decimals)
            sentence = "\(name): \(valueText) \(unit) of a \(goalText) \(unit) goal — GOAL EXCEEDED by \(over) \(unit) (\(percent)% of goal). \(pointsText)."
        }

        return CoachMetricStatus(
            name: name,
            level: level,
            value: value,
            goal: goal,
            unit: unit,
            points: points,
            maxPoints: maxPoints,
            sentence: sentence
        )
    }

    private static func format(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(max(decimals, 0))f", value)
    }
}
