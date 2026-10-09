import Foundation

enum CoachSnapshotBuilder {
    static func build(
        today: DailyRecord,
        records: [DailyRecord],
        goals: [SMARTGoal] = [],
        hrvSensitivity: HRVSensitivity = .balanced,
        phase: DayPhase = .current(),
        now: Date = Date(),
        calendar: Calendar = .current,
        bodyTrend: BodyTrend? = nil,
        nutritionMode: NutritionMode = .fiber,
        scoringSettings: UserSettings? = nil
    ) -> CoachSnapshot {
        let settings = scoringSettings ?? UserSettings(
            sleepGoal: today.sleepGoal,
            fiberGoal: .forty,
            movementGoal: today.movementGoal,
            nutritionMode: nutritionMode
        )
        let filledWeek = CompletedTrendBuilder.filledRecords(
            days: 7,
            records: records,
            settings: settings,
            now: now,
            calendar: calendar
        )
        let weekKeys = filledWeek.map(\.date)
        let weekStats = weekKeys.isEmpty
            ? nil
            : RollingStatsCalculator.compute(
                records: filledWeek,
                windowKeys: weekKeys,
                nutritionMode: settings.nutritionMode,
                movementGoal: settings.movementGoal
            )
        let fiberDays = records.filter { record in
            guard weekKeys.contains(record.date) else { return false }
            if settings.nutritionMode == .foodGroups { return record.foodGroups.isLogged }
            return record.fiberGrams > 0
        }.count

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
            timeOfDay: CoachTimeOfDay.current(from: now, calendar: calendar),
            clockLabel: CoachClock.promptLabel(from: now, calendar: calendar),
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
            fiber: nutritionStatus(for: today, mode: settings.nutritionMode),
            exercise: movementStatus(for: today, goal: settings.movementGoal),
            primaryFocus: today.primaryFocus,
            weekDaysWithData: weekStats?.daysWithData ?? 0,
            weekAvgScore: weekStats?.avgTotalScore,
            weekAvgSleep: CompletedTrendBuilder.build(
                metric: .sleep, records: records, settings: settings, now: now, calendar: calendar
            )?.average,
            weekAvgFiber: CompletedTrendBuilder.build(
                metric: .fiber, records: records, settings: settings, now: now, calendar: calendar
            )?.average,
            weekAvgExercise: CompletedTrendBuilder.build(
                metric: .movement, records: records, settings: settings, now: now, calendar: calendar
            )?.average,
            fiberDaysLoggedInWeek: fiberDays,
            hrvSummary: hrvSummary,
            smartGoals: CoachGoalSummarizer.lines(for: goals),
            bodyLine: bodyTrend?.promptBlock
        )
    }

    static func nutritionStatus(for record: DailyRecord, mode: NutritionMode) -> CoachMetricStatus {
        switch mode {
        case .foodGroups:
            let glance = FoodGroupScore.glance(record.foodGroups)
            let points = FoodGroupScore.points(record.foodGroups)
            var metric = status(
                name: "Food groups",
                value: points,
                goal: 4,
                unit: "pts",
                decimals: 1,
                points: points,
                maxPoints: 4,
                treatZeroAsMissing: !glance.isLogged
            )
            if glance.isLogged {
                metric.sentence += " \(glance.prose)."
            }
            return metric
        case .fiber:
            return status(
                name: "Fiber",
                value: record.fiberGrams,
                goal: UserSettings.fiberGoalGrams,
                unit: "g",
                decimals: 1,
                points: record.fiberScore,
                maxPoints: 4
            )
        }
    }

    static func movementStatus(for record: DailyRecord, goal selected: MovementGoal? = nil) -> CoachMetricStatus {
        let goal = selected ?? record.movementGoal
        let value = goal.countsSteps ? record.stepCount : record.exerciseMinutes
        let points = goal == record.movementGoal
            ? record.exerciseScore
            : ScoreCalculator.movementPoints(value: value, goal: goal.goalValue)
        return status(
            name: goal.metricName,
            value: value,
            goal: goal.goalValue,
            unit: goal.unit,
            decimals: 0,
            points: points,
            maxPoints: 2
        )
    }

    /// The recorded value and the goal. What that means is left to the model.
    static func status(
        name: String,
        value: Double,
        goal: Double,
        unit: String,
        decimals: Int,
        points: Double,
        maxPoints: Double,
        treatZeroAsMissing: Bool = true
    ) -> CoachMetricStatus {
        let level: CoachMetricLevel
        if treatZeroAsMissing && value <= 0 {
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
        let pointsText = String(format: "%.1f of %.0f points", points, maxPoints)

        let sentence: String
        if level == .missing {
            sentence = "\(name): unlogged. Goal \(goalText) \(unit)."
        } else {
            sentence = "\(name): \(valueText) \(unit). Goal \(goalText) \(unit). \(pointsText)."
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
