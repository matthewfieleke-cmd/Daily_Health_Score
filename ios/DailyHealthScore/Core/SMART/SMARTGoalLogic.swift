import Foundation

enum SMARTGoalLogic {
    static let minTimeWindowDays = 1
    static let maxTimeWindowDays = 30
    static let achievableReminder = "Make sure this goal is something you can actually accomplish in the time window you choose."

    /// End date from creation + the user-selected day window.
    static func endDate(createdAt: Date = Date(), days: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: clampedDays(days), to: createdAt) ?? createdAt
    }

    static func clampedDays(_ days: Int) -> Int {
        max(minTimeWindowDays, min(days, maxTimeWindowDays))
    }

    static func clampedTargetCount(_ count: Int) -> Int {
        max(1, min(count, 30))
    }

    static func buildSummary(
        specific: String,
        targetCount: Int,
        theme: SMARTRelevantTheme,
        timeWindowDays: Int,
        endDate: Date
    ) -> String {
        let by = endDate.formatted(.dateTime.month(.wide).day().year().hour().minute())
        let count = clampedTargetCount(targetCount)
        let days = clampedDays(timeWindowDays)
        let times = count == 1 ? "time" : "times"
        let dayLabel = days == 1 ? "day" : "days"
        return "I will \(specific.trimmingCharacters(in: .whitespacesAndNewlines)) \(count) \(times) within \(days) \(dayLabel) because it supports \(theme.label.lowercased()), completing it by \(by)."
    }

    /// Badge: active goals that still need check-ins (not complete, not past end).
    static func attentionCount(goals: [SMARTGoal]) -> Int {
        goals.filter { $0.status == .active && !$0.isComplete && !$0.isExpired }.count
    }
}
