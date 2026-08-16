import Foundation

/// Deterministic Home-card copy when the model is unavailable, and a status
/// paragraph the UI can always show as complete sentences.
enum HomeCoachCardCopy {
    static func whereYouAre(for record: DailyRecord) -> String {
        let sleep = CoachSnapshotBuilder.status(
            name: "Sleep",
            value: record.sleepHours,
            goal: record.sleepGoal.rawValue,
            unit: "h",
            decimals: 1,
            points: record.sleepScore,
            maxPoints: 4
        )
        let fiber = CoachSnapshotBuilder.status(
            name: "Fiber",
            value: record.fiberGrams,
            goal: Double(record.fiberGoal.rawValue),
            unit: "g",
            decimals: 1,
            points: record.fiberScore,
            maxPoints: 4
        )
        let exercise = CoachSnapshotBuilder.status(
            name: "Exercise",
            value: record.exerciseMinutes,
            goal: Double(record.exerciseGoalMinutes),
            unit: "min",
            decimals: 0,
            points: record.exerciseScore,
            maxPoints: 2
        )
        let score = ScoreCalculator.formatDisplayScore(record.totalScore)
        return "You're at \(score) of 10 today. \(compact(sleep, decimals: 1)) \(compact(fiber, decimals: 1)) \(compact(exercise, decimals: 0))"
    }

    /// Home-sized status line. Exact goal words, without the prompt's point math.
    private static func compact(_ metric: CoachMetricStatus, decimals: Int) -> String {
        let value = String(format: "%.\(max(decimals, 0))f", metric.value)
        let goalDecimals = metric.goal.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        let goal = String(format: "%.\(goalDecimals)f", metric.goal)
        switch metric.level {
        case .missing:
            return "\(metric.name) is unlogged — NO DATA, not a zero (goal \(goal) \(metric.unit))."
        case .below:
            return "\(metric.name) is \(value) \(metric.unit) — BELOW GOAL (goal \(goal) \(metric.unit))."
        case .met:
            return "\(metric.name) is \(value) \(metric.unit) — GOAL MET."
        case .exceeded:
            return "\(metric.name) is \(value) \(metric.unit) — GOAL EXCEEDED (goal \(goal) \(metric.unit))."
        }
    }

    static func nextMove(
        for record: DailyRecord,
        timeOfDay: CoachTimeOfDay
    ) -> String {
        if record.primaryFocus == .maintain {
            return maintenanceMove(timeOfDay)
        }
        switch record.primaryFocus {
        case .fiber: return fiberMove(timeOfDay)
        case .exercise: return exerciseMove(timeOfDay)
        case .sleep: return sleepMove(timeOfDay)
        case .maintain: return maintenanceMove(timeOfDay)
        }
    }

    static func fallbackCard(
        for record: DailyRecord,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DailyCoachCardContent {
        let time = CoachTimeOfDay.current(from: now, calendar: calendar)
        return DailyCoachCardContent(
            whereYouAre: whereYouAre(for: record),
            nextMove: nextMove(for: record, timeOfDay: time)
        )
    }

    private static func fiberMove(_ time: CoachTimeOfDay) -> String {
        switch time {
        case .morning, .midday:
            return "At lunch, add beans, berries, or a whole grain to the plate you already planned."
        case .afternoon:
            return "Have a pear, berries, or leftover vegetables this afternoon — lunch has passed."
        case .evening:
            return "Put beans, a pear, or leftover vegetables on dinner. Lunch is done."
        case .night:
            return "If you eat anything else tonight, make it fruit or leftover vegetables, then pick one fiber-rich lunch for tomorrow."
        }
    }

    private static func exerciseMove(_ time: CoachTimeOfDay) -> String {
        switch time {
        case .morning:
            return "Take a 10-minute brisk walk before lunch."
        case .midday:
            return "Walk 10 minutes after you eat lunch, while you are already up."
        case .afternoon:
            return "Take a 10-minute brisk walk now, before evening energy dips."
        case .evening:
            return "Walk 10 minutes after dinner, or set your shoes by the door for tomorrow morning."
        case .night:
            return "Skip a late workout. Set your shoes by the door and walk 10 minutes tomorrow morning."
        }
    }

    private static func sleepMove(_ time: CoachTimeOfDay) -> String {
        switch time {
        case .morning, .midday:
            return "Park caffeine by early afternoon so tonight's sleep has a chance."
        case .afternoon:
            return "Keep caffeine off the table from here, and dim bright screens after dinner."
        case .evening, .night:
            return "Dim screens and keep the room cool — the useful sleep work tonight is wind-down, not a daytime plan."
        }
    }

    private static func maintenanceMove(_ time: CoachTimeOfDay) -> String {
        switch time {
        case .morning, .midday:
            return "Protect the afternoon: water, a fiber-rich lunch, and one planned snack so evening you is not scavenging."
        case .afternoon:
            return "You are on track — take a short walk and decide tonight's snack now, while you still have choice."
        case .evening, .night:
            return "Protect the win: a calm wind-down tonight rather than extra credit that costs sleep."
        }
    }
}
