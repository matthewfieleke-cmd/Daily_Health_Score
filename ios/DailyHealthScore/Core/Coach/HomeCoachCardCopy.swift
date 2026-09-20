import Foundation

/// Deterministic check-in copy for when the model is unavailable, and the
/// health sentence every card can fall back to. Complete sentences, no tokens.
enum HomeCoachCardCopy {
    /// One spoken sentence about today. Never prints status tokens.
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

    /// Evening voice: the day is mostly written, so reflect instead of steering.
    static func eveningLine(for record: DailyRecord) -> String {
        let score = ScoreCalculator.formatDisplayScore(record.totalScore)
        switch record.primaryFocus {
        case .sleep:
            return "Today landed at \(score) of 10 on a short night — you carried the day anyway."
        case .fiber:
            return "Today landed at \(score) of 10; fiber was the pillar that ran light."
        case .exercise:
            return "Today landed at \(score) of 10; movement was the pillar that ran light."
        case .maintain:
            return "Today landed at \(score) of 10 — all three pillars showed up."
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

    /// The whole card without a model: a health line, a question, and (evening)
    /// one thing for tomorrow. Questions rotate on the day so the card does not
    /// read identically every morning.
    static func fallbackCheckIn(
        for record: DailyRecord,
        kind: CoachCheckInKind,
        trend: CoachTrendDigest? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> CoachCheckIn {
        let dayIndex = (calendar.ordinality(of: .day, in: .year, for: now) ?? 0)
        switch kind {
        case .morning:
            let questions = [
                "What is the one thing worth protecting today?",
                "Where will today get hard, and what would make it a little easier?",
                "What would make tonight feel like a good day when you look back?",
                "Who do you want to show up for today?"
            ]
            return CoachCheckIn(
                kind: .morning,
                dateKey: record.date,
                healthLine: healthLine(for: record),
                question: questions[dayIndex % questions.count],
                trendLine: trend?.sentence ?? "",
                isFallback: true,
                generatedAt: now
            )
        case .evening:
            let questions = [
                "What went better today than the numbers show?",
                "What got in the way today, and was it new or familiar?",
                "What did you do today that your future self will thank you for?",
                "What is one thing you would do differently tomorrow?"
            ]
            return CoachCheckIn(
                kind: .evening,
                dateKey: record.date,
                healthLine: eveningLine(for: record),
                question: questions[dayIndex % questions.count],
                tomorrowLine: tomorrowLine(for: record),
                isFallback: true,
                generatedAt: now
            )
        }
    }

    static func tomorrowLine(for record: DailyRecord) -> String {
        switch record.primaryFocus {
        case .sleep:
            return "Tomorrow, one thing: pick a lights-out time now and protect the half hour before it."
        case .fiber:
            return "Tomorrow, one thing: decide one fiber-rich lunch tonight so noon takes no willpower."
        case .exercise:
            return "Tomorrow, one thing: put your shoes by the door and walk ten minutes before the day fills up."
        case .maintain:
            return "Tomorrow, one thing: repeat what worked today — nothing new, nothing extra."
        }
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
