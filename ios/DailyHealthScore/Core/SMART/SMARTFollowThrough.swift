import Foundation

struct SMARTFollowThroughSettings: Equatable, Codable, Sendable {
    var quietHoursEnabled: Bool = true
    var quietHoursStartHour: Int = 21
    var quietHoursEndHour: Int = 7
    var snoozeMinutes: Int = 120

    static let `default` = SMARTFollowThroughSettings()
}

enum SMARTFollowThroughKind: String, Codable, Sendable {
    case checkInReminder
    case reflection
    case weeklyReview

    var title: String {
        switch self {
        case .checkInReminder: return "SMART goal check-in"
        case .reflection: return "Quick reflection"
        case .weeklyReview: return "Goal review"
        }
    }
}

struct SMARTFollowThroughDecision: Equatable, Sendable {
    var kind: SMARTFollowThroughKind
    var goalId: UUID
    var fireDate: Date
    var title: String
    var body: String
    var dateKey: String
}

enum SMARTFollowThroughLogic {
    static let maxCheckInRemindersPerDay = 1
    static let reviewAfterDays = 7

    static func isWithinQuietHours(
        _ date: Date,
        settings: SMARTFollowThroughSettings,
        calendar: Calendar = .current
    ) -> Bool {
        guard settings.quietHoursEnabled else { return false }
        let hour = calendar.component(.hour, from: date)
        let start = settings.quietHoursStartHour
        let end = settings.quietHoursEndHour
        if start == end { return false }
        if start < end {
            return hour >= start && hour < end
        }
        return hour >= start || hour < end
    }

    static func nextAllowedFireDate(
        from date: Date,
        settings: SMARTFollowThroughSettings,
        calendar: Calendar = .current
    ) -> Date {
        guard isWithinQuietHours(date, settings: settings, calendar: calendar) else { return date }
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = settings.quietHoursEndHour
        components.minute = 0
        let sameDayEnd = calendar.date(from: components) ?? date
        if settings.quietHoursStartHour > settings.quietHoursEndHour {
            if calendar.component(.hour, from: date) >= settings.quietHoursStartHour {
                return calendar.date(byAdding: .day, value: 1, to: sameDayEnd) ?? date
            }
            return max(sameDayEnd, date)
        }
        return max(sameDayEnd, date)
    }

    static func decisions(
        goals: [SMARTGoal],
        activitiesByGoal: [UUID: [SMARTGoalActivity]],
        states: [UUID: CoachFollowThroughState],
        settings: SMARTFollowThroughSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [SMARTFollowThroughDecision] {
        let todayKey = DateHelpers.localDateKey(from: now)
        var results: [SMARTFollowThroughDecision] = []
        for goal in goals where goal.plan.followThroughEnabled {
            guard goal.status == .active, !goal.isComplete, !goal.isExpired, !goal.isPaused else { continue }
            let state = states[goal.id] ?? CoachFollowThroughState(goalId: goal.id)
            if let snooze = state.snoozeUntil, snooze > now { continue }
            if state.dismissedDateKey == todayKey { continue }

            if let reminder = checkInDecision(
                goal: goal,
                state: state,
                settings: settings,
                now: now,
                todayKey: todayKey,
                calendar: calendar
            ) {
                results.append(reminder)
            }
            if let reflection = reflectionDecision(
                goal: goal,
                events: activitiesByGoal[goal.id] ?? [],
                state: state,
                settings: settings,
                now: now,
                todayKey: todayKey,
                calendar: calendar
            ) {
                results.append(reflection)
            }
            if let review = reviewDecision(
                goal: goal,
                state: state,
                settings: settings,
                now: now,
                calendar: calendar
            ) {
                results.append(review)
            }
        }
        return results
    }

    static func notificationIdentifier(kind: SMARTFollowThroughKind, goalId: UUID, dateKey: String) -> String {
        "follow-through-\(kind.rawValue)-\(goalId.uuidString)-\(dateKey)"
    }

    private static func checkInDecision(
        goal: SMARTGoal,
        state: CoachFollowThroughState,
        settings: SMARTFollowThroughSettings,
        now: Date,
        todayKey: String,
        calendar: Calendar
    ) -> SMARTFollowThroughDecision? {
        if let last = state.lastReminderAt, DateHelpers.localDateKey(from: last) == todayKey {
            return nil
        }
        var fire = calendar.date(
            bySettingHour: goal.reminderHour,
            minute: goal.reminderMinute,
            second: 0,
            of: now
        ) ?? now
        if fire <= now {
            fire = calendar.date(byAdding: .day, value: 1, to: fire) ?? fire
        }
        fire = nextAllowedFireDate(from: fire, settings: settings, calendar: calendar)
        return SMARTFollowThroughDecision(
            kind: .checkInReminder,
            goalId: goal.id,
            fireDate: fire,
            title: SMARTFollowThroughKind.checkInReminder.title,
            body: "A reminder for \(goal.specificText). Logging is optional — a missing check-in does not mean you missed it.",
            dateKey: DateHelpers.localDateKey(from: fire)
        )
    }

    private static func reflectionDecision(
        goal: SMARTGoal,
        events: [SMARTGoalActivity],
        state: CoachFollowThroughState,
        settings: SMARTFollowThroughSettings,
        now: Date,
        todayKey: String,
        calendar: Calendar
    ) -> SMARTFollowThroughDecision? {
        if let last = state.lastReflectionAt, DateHelpers.localDateKey(from: last) == todayKey {
            return nil
        }
        let datedToday = SMARTGoalActivityLogic.activeCheckIns(in: events)
            .contains { $0.localDateKey == todayKey }
        guard datedToday else { return nil }
        var fire = calendar.date(
            bySettingHour: goal.plan.reflectionHour,
            minute: goal.plan.reflectionMinute,
            second: 0,
            of: now
        ) ?? now
        if fire <= now { return nil }
        fire = nextAllowedFireDate(from: fire, settings: settings, calendar: calendar)
        return SMARTFollowThroughDecision(
            kind: .reflection,
            goalId: goal.id,
            fireDate: fire,
            title: SMARTFollowThroughKind.reflection.title,
            body: "If you want, note what helped or got in the way of \(goal.specificText). Skip anything that did not happen.",
            dateKey: todayKey
        )
    }

    private static func reviewDecision(
        goal: SMARTGoal,
        state: CoachFollowThroughState,
        settings: SMARTFollowThroughSettings,
        now: Date,
        calendar: Calendar
    ) -> SMARTFollowThroughDecision? {
        let last = state.lastReviewAt ?? goal.createdAt
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
        guard days >= reviewAfterDays else { return nil }
        if let lastReview = state.lastReviewAt,
           DateHelpers.localDateKey(from: lastReview) == DateHelpers.localDateKey(from: now) {
            return nil
        }
        var fire = calendar.date(byAdding: .hour, value: 1, to: now) ?? now
        fire = nextAllowedFireDate(from: fire, settings: settings, calendar: calendar)
        return SMARTFollowThroughDecision(
            kind: .weeklyReview,
            goalId: goal.id,
            fireDate: fire,
            title: SMARTFollowThroughKind.weeklyReview.title,
            body: "Optional review of \(goal.specificText). You can keep the plan, rest, or choose an easier version. Nothing is saved until you review it.",
            dateKey: DateHelpers.localDateKey(from: fire)
        )
    }
}
