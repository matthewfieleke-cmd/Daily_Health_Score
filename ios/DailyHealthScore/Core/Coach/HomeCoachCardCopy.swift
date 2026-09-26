import Foundation

/// Deterministic check-in copy for when the model is unavailable, and the
/// sentence every card can fall back to. Complete sentences, no tokens, and
/// no numbers: the tiles above the card carry those live.
enum HomeCoachCardCopy {
    /// Before Health has synced anything for today.
    static let waitingLine = "Nothing from Apple Health for today yet — this note writes itself once the first numbers land."

    /// One spoken sentence about the shape of today. Never prints status tokens.
    static func healthLine(for record: DailyRecord) -> String {
        guard CoachCheckInLogic.hasData(record) else { return waitingLine }
        switch record.primaryFocus {
        case .sleep:
            return "Short night behind you — the day is still wide open, and food and a walk can carry it."
        case .fiber:
            return "Food is the pillar with the most room today, and most of the day is still ahead of you."
        case .exercise:
            return "Movement is the pillar with the most room today, if you want it."
        case .maintain:
            return "All three pillars are in a good place so far — today is about protecting that, not adding to it."
        }
    }

    /// Evening voice: the day is mostly written, so reflect instead of steering.
    static func eveningLine(for record: DailyRecord) -> String {
        guard CoachCheckInLogic.hasData(record) else { return waitingLine }
        switch record.primaryFocus {
        case .sleep:
            return "Today ran on a short night, and you carried it anyway."
        case .fiber:
            return "Fiber was the pillar that ran light today."
        case .exercise:
            return "Movement was the pillar that ran light today."
        case .maintain:
            return "All three pillars showed up today."
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

    /// The whole card without a model: one plain line. Not a fake list of
    /// thoughts, and not a question written in to look like the Coach.
    static func fallbackCheckIn(
        for record: DailyRecord,
        kind: CoachCheckInKind,
        now: Date = Date()
    ) -> CoachCheckIn {
        let line = kind == .morning ? healthLine(for: record) : eveningLine(for: record)
        return CoachCheckIn(
            kind: kind,
            dateKey: record.date,
            healthLine: line,
            thoughts: [line],
            isFallback: true,
            generatedAt: now
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
