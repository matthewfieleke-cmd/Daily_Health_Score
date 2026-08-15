import Foundation

/// Time-aware fiber and exercise nudges.
///
/// Sleep is finished in the morning and must never trigger these. The total
/// Daily Health Score is ignored for the same reason. Three clock times, a
/// rising bar, quiet outside that window, at most one notification per slot.
enum PaceNudgeSlot: String, CaseIterable, Codable, Sendable {
    case afternoon
    case lateAfternoon
    case evening

    var hour: Int {
        switch self {
        case .afternoon: return 14
        case .lateAfternoon: return 17
        case .evening: return 19
        }
    }

    var minute: Int {
        switch self {
        case .afternoon: return 30
        case .lateAfternoon: return 30
        case .evening: return 30
        }
    }

    /// Fire fiber if today's grams are strictly below this fraction of the goal.
    var fiberFraction: Double {
        switch self {
        case .afternoon: return 0.20
        case .lateAfternoon: return 0.45
        case .evening: return 0.70
        }
    }

    /// Fire exercise if today's minutes are strictly below this fraction of the goal.
    var exerciseFraction: Double {
        switch self {
        case .afternoon: return 0.20
        case .lateAfternoon: return 0.50
        case .evening: return 0.80
        }
    }

    var notificationIdentifier: String { "dhs.pace.\(rawValue)" }

    func dateComponents(on day: Date, calendar: Calendar) -> DateComponents {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return components
    }

    func fireDate(on day: Date, calendar: Calendar) -> Date? {
        calendar.date(from: dateComponents(on: day, calendar: calendar))
    }

    func hasPassed(at now: Date, calendar: Calendar) -> Bool {
        guard let fire = fireDate(on: now, calendar: calendar) else { return false }
        return now >= fire
    }
}

enum PaceNudgeKind: String, Equatable, Sendable {
    case fiber
    case exercise
    case combined
}

struct PaceNudgeDecision: Equatable, Sendable {
    var slot: PaceNudgeSlot
    var kind: PaceNudgeKind
    var title: String
    var body: String
}

enum PaceNudgeLogic {
    /// No pace nudges before the first check or after this evening bound.
    static let quietAfterHour = 20
    static let quietAfterMinute = 30

    static func fiberThreshold(goal: Double, slot: PaceNudgeSlot) -> Double {
        goal * slot.fiberFraction
    }

    static func exerciseThreshold(goal: Double, slot: PaceNudgeSlot) -> Double {
        goal * slot.exerciseFraction
    }

    /// Decision for one upcoming (or current) slot using live Health numbers.
    /// Returns nil when that pillar is on pace, the slot already passed (if
    /// requested), or we are in quiet hours for a "right now" evaluation.
    static func decision(
        for slot: PaceNudgeSlot,
        fiberGrams: Double,
        fiberGoal: Double,
        exerciseMinutes: Double,
        exerciseGoal: Double,
        now: Date = Date(),
        calendar: Calendar = .current,
        skipIfAlreadyPassed: Bool = true
    ) -> PaceNudgeDecision? {
        if skipIfAlreadyPassed, slot.hasPassed(at: now, calendar: calendar) {
            return nil
        }

        let fiberBehind = fiberGoal > 0 && fiberGrams < fiberThreshold(goal: fiberGoal, slot: slot)
        let exerciseBehind = exerciseGoal > 0 && exerciseMinutes < exerciseThreshold(goal: exerciseGoal, slot: slot)

        switch (fiberBehind, exerciseBehind) {
        case (true, true):
            return PaceNudgeDecision(
                slot: slot,
                kind: .combined,
                title: "Fiber and movement",
                body: combinedCopy(
                    slot: slot,
                    fiberGrams: fiberGrams,
                    fiberGoal: fiberGoal,
                    exerciseMinutes: exerciseMinutes,
                    exerciseGoal: exerciseGoal
                )
            )
        case (true, false):
            return PaceNudgeDecision(
                slot: slot,
                kind: .fiber,
                title: "Fiber",
                body: fiberCopy(slot: slot, grams: fiberGrams, goal: fiberGoal)
            )
        case (false, true):
            return PaceNudgeDecision(
                slot: slot,
                kind: .exercise,
                title: "Movement",
                body: exerciseCopy(slot: slot, minutes: exerciseMinutes, goal: exerciseGoal)
            )
        case (false, false):
            return nil
        }
    }

    /// All not-yet-passed slots for today that should fire, in clock order.
    static func upcomingDecisions(
        fiberGrams: Double,
        fiberGoal: Double,
        exerciseMinutes: Double,
        exerciseGoal: Double,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [PaceNudgeDecision] {
        PaceNudgeSlot.allCases.compactMap { slot in
            decision(
                for: slot,
                fiberGrams: fiberGrams,
                fiberGoal: fiberGoal,
                exerciseMinutes: exerciseMinutes,
                exerciseGoal: exerciseGoal,
                now: now,
                calendar: calendar,
                skipIfAlreadyPassed: true
            )
        }
    }

    static func isInQuietHours(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let first = PaceNudgeSlot.afternoon.fireDate(on: now, calendar: calendar)
        let lastBound = calendar.date(
            bySettingHour: quietAfterHour,
            minute: quietAfterMinute,
            second: 0,
            of: now
        )
        guard let first, let lastBound else { return true }
        return now < first || now >= lastBound
    }

    private static func combinedCopy(
        slot: PaceNudgeSlot,
        fiberGrams: Double,
        fiberGoal: Double,
        exerciseMinutes: Double,
        exerciseGoal: Double
    ) -> String {
        let gramsText = Int(fiberGrams.rounded())
        let fiberGoalText = Int(fiberGoal.rounded())
        let minutesText = Int(exerciseMinutes.rounded())
        let exerciseGoalText = Int(exerciseGoal.rounded())
        switch slot {
        case .afternoon:
            return "Movement is at \(minutesText) of \(exerciseGoalText) min and fiber is \(gramsText) of \(fiberGoalText) g. A short walk plus beans, berries, or a salad — or log a meal on iPhone — will get both on the board."
        case .lateAfternoon:
            return "Still \(minutesText) of \(exerciseGoalText) min and \(gramsText) of \(fiberGoalText) g fiber. A brisk walk before dinner and a high-fiber dinner (or log it on iPhone) will catch this up."
        case .evening:
            return "Still short: \(minutesText) of \(exerciseGoalText) min and \(gramsText) of \(fiberGoalText) g fiber. A short walk and logging tonight’s food on iPhone — or a cup of beans or fruit — is enough."
        }
    }

    private static func fiberCopy(slot: PaceNudgeSlot, grams: Double, goal: Double) -> String {
        let gramsText = Int(grams.rounded())
        let goalText = Int(goal.rounded())
        switch slot {
        case .afternoon:
            return "Fiber is still low in Health (\(gramsText) g of \(goalText) g). If you already ate, log the meal on iPhone; if not, beans, berries, oats, or a big salad at the next meal will move this."
        case .lateAfternoon:
            return "You’re at \(gramsText) g of \(goalText) g of fiber. Dinner is the easiest place to close that — or log it on iPhone if dinner already happened."
        case .evening:
            return "Fiber still isn’t near goal (\(gramsText) g of \(goalText) g). If tonight’s food isn’t in Health yet, log it on iPhone; if it is, a cup of beans or fruit will do more than another snack without it."
        }
    }

    private static func exerciseCopy(slot: PaceNudgeSlot, minutes: Double, goal: Double) -> String {
        let minutesText = Int(minutes.rounded())
        let goalText = Int(goal.rounded())
        let remaining = max(Int((goal - minutes).rounded()), 0)
        switch slot {
        case .afternoon:
            return "Exercise is still at \(minutesText) of \(goalText) min. A 15-minute walk this afternoon is enough to get on the board."
        case .lateAfternoon:
            return "\(remaining) min left in the \(goalText)-minute goal. That’s one brisk walk before dinner."
        case .evening:
            return "Still short on movement (\(minutesText) of \(goalText) min). A short walk tonight is enough; this is not a workout."
        }
    }
}
