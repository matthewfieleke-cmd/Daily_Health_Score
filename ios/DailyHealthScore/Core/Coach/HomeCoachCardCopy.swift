import Foundation

/// Deterministic Home-card copy when the model is unavailable, and a status
/// paragraph the UI can always show as complete sentences.
enum HomeCoachCardCopy {
    static func whereYouAre(for record: DailyRecord) -> String {
        healthLine(for: record)
    }

    /// One spoken sentence. Never prints status tokens.
    static func healthLine(for record: DailyRecord) -> String {
        let score = ScoreCalculator.formatDisplayScore(record.totalScore)
        switch record.primaryFocus {
        case .sleep:
            return "You're at \(score) of 10 — last night's sleep was shorter than the night you wanted."
        case .fiber:
            return "You're at \(score) of 10 — food still has room before the day is done."
        case .exercise:
            return "You're at \(score) of 10 — movement still has room if you want it."
        case .maintain:
            return "You're at \(score) of 10 — the three pillars are in a good place today."
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
            whereYouAre: healthLine(for: record),
            nextMove: nextMove(for: record, timeOfDay: time),
            healthLine: healthLine(for: record)
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
