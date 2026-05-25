import Foundation

enum SMARTGoalLogic {
    /// End date from creation + preset (+7 days for one week, etc.).
    static func endDate(createdAt: Date = Date(), preset: SMARTTimePreset) -> Date {
        let calendar = Calendar.current
        switch preset {
        case .oneHour:
            return calendar.date(byAdding: .hour, value: 1, to: createdAt) ?? createdAt
        case .oneDay:
            return calendar.date(byAdding: .day, value: 1, to: createdAt) ?? createdAt
        case .oneWeek:
            return calendar.date(byAdding: .day, value: 7, to: createdAt) ?? createdAt
        }
    }

    static func targetCount(pattern: SMARTMeasurablePattern, sessionCount: Int) -> Int {
        switch pattern {
        case .sessionsInWindow: return max(1, min(sessionCount, 7))
        case .dailyForSevenDays: return 7
        case .onceWithConfirm: return 1
        }
    }

    static func defaultMeasurablePattern(sessionCount: Int, dailyForWeek: Bool) -> SMARTMeasurablePattern {
        if dailyForWeek { return .dailyForSevenDays }
        if sessionCount == 1 { return .onceWithConfirm }
        return .sessionsInWindow
    }

    static func achievableSuggestion(
        category: SMARTGoalCategory,
        records: [DailyRecord],
        settings: UserSettings
    ) -> String {
        guard category.isHealthPillar else {
            return "Choose a target that fits your week."
        }

        let keys = DateHelpers.rollingDateKeys(days: 7)
        let keySet = Set(keys)
        let week = records.filter { keySet.contains($0.date) }
        guard !week.isEmpty else {
            return defaultAchievableHint(category: category, settings: settings)
        }

        switch category {
        case .sleep:
            let avg = week.map(\.sleepHours).reduce(0, +) / Double(week.count)
            let goal = settings.sleepGoal.rawValue
            if avg >= goal * 0.95 {
                return "You're averaging \(ScoreCalculator.formatDisplayScore(avg)) hr — maintaining \(settings.sleepGoal.label) hr is realistic."
            }
            return "You're averaging \(ScoreCalculator.formatDisplayScore(avg)) hr — aim toward \(settings.sleepGoal.label) hr sleep."
        case .fiber:
            let avg = week.map(\.fiberGrams).reduce(0, +) / Double(week.count)
            let goal = Double(settings.fiberGoal.rawValue)
            return "You're averaging \(ScoreCalculator.formatDisplayScore(avg)) g — \(Int(goal)) g is your current daily goal."
        case .exercise:
            let avg = week.map(\.exerciseMinutes).reduce(0, +) / Double(week.count)
            return "You're averaging \(Int(avg.rounded())) min — 30 min is your exercise goal."
        default:
            return defaultAchievableHint(category: category, settings: settings)
        }
    }

    static func defaultAchievableHint(category: SMARTGoalCategory, settings: UserSettings) -> String {
        switch category {
        case .sleep: return "Aim for \(settings.sleepGoal.label) hours of sleep on most nights."
        case .fiber: return "Aim for \(settings.fiberGoal.rawValue) g of fiber on most days."
        case .exercise: return "Aim for 30 minutes of exercise on active days."
        default: return "Choose a target that fits your week."
        }
    }

    static func defaultMeasurableDescription(
        category: SMARTGoalCategory,
        settings: UserSettings,
        pattern: SMARTMeasurablePattern,
        sessionCount: Int
    ) -> String {
        switch pattern {
        case .dailyForSevenDays:
            return healthMeasurableUnit(category: category, settings: settings) + " — once each day for 7 days"
        case .onceWithConfirm:
            return "Complete once"
        case .sessionsInWindow:
            if category.isHealthPillar {
                return "\(sessionCount)× \(healthMeasurableUnit(category: category, settings: settings)) in the goal window"
            }
            return "\(sessionCount) session\(sessionCount == 1 ? "" : "s") in the goal window"
        }
    }

    static func healthMeasurableUnit(category: SMARTGoalCategory, settings: UserSettings) -> String {
        switch category {
        case .sleep: return "\(settings.sleepGoal.label) hr sleep"
        case .fiber: return "\(settings.fiberGoal.rawValue) g fiber"
        case .exercise: return "30 min exercise"
        default: return "session"
        }
    }

    static func buildSummary(
        specific: String,
        measurable: String,
        achievable: String,
        theme: SMARTRelevantTheme,
        endDate: Date
    ) -> String {
        let by = endDate.formatted(.dateTime.month(.wide).day().year().hour().minute())
        return "I will \(specific.trimmingCharacters(in: .whitespacesAndNewlines)), \(measurable), \(achievable). This matters for \(theme.label.lowercased()) by \(by)."
    }

    /// Badge: active goals that still need check-ins (not complete, not past end).
    static func attentionCount(goals: [SMARTGoal]) -> Int {
        goals.filter { $0.status == .active && !$0.isComplete && !$0.isExpired }.count
    }
}
