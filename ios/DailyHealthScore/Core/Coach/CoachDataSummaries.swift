import Foundation

/// Turns SMART goals and HRV into facts. Counts and dates are computed here.
/// A count is not a daily schedule, and the list is every saved goal.
enum CoachGoalSummarizer {
    /// Goal text is free-form and user-entered; one long entry must not crowd
    /// out the rest of the prompt.
    static let maxTitleLength = 80

    static func lines(
        for goals: [SMARTGoal],
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> [String] {
        // Active goals first, then by nearest deadline: what needs attention leads.
        let ordered = goals.sorted { lhs, rhs in
            let lhsActive = isActive(lhs, at: today)
            let rhsActive = isActive(rhs, at: today)
            if lhsActive != rhsActive { return lhsActive }
            return lhsActive ? lhs.endDate < rhs.endDate : lhs.endDate > rhs.endDate
        }
        return ordered.map { line(for: $0, today: today, calendar: calendar) }
    }

    private static func isActive(_ goal: SMARTGoal, at date: Date) -> Bool {
        goal.status == .active && !goal.isComplete && goal.endDate > date
    }

    static func line(
        for goal: SMARTGoal,
        today: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let title = goal.specificText.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = title.isEmpty ? "Untitled goal" : title.limitedToCoachBudget(maxTitleLength)
        let progress = "\(goal.filledCount) of \(goal.targetCount) check-ins"
        let theme = goal.relevantTheme.label

        if goal.isComplete {
            return "\"\(name)\" (\(theme)): \(progress). Complete."
        }
        if goal.isPaused {
            return "\"\(name)\" (\(theme)): \(progress). Paused."
        }
        if goal.endDate <= today || goal.status == .ended {
            return "\"\(name)\" (\(theme)): \(progress). Ended."
        }

        let remaining = max(goal.targetCount - goal.filledCount, 0)
        let days = daysRemaining(until: goal.endDate, from: today, calendar: calendar)
        let window: String
        switch days {
        case 0: window = "ends today"
        case 1: window = "1 day left"
        default: window = "\(days) days left"
        }
        // A count does not specify a daily schedule: several actions may fit in
        // one day. Report facts instead of inventing an on-track judgement.
        return "\"\(name)\" (\(theme)): \(progress), \(window) (\(remaining) to go)."
    }

    /// Whole days between today and the deadline, never negative.
    static func daysRemaining(
        until endDate: Date,
        from today: Date,
        calendar: Calendar = .current
    ) -> Int {
        let start = calendar.startOfDay(for: today)
        let end = calendar.startOfDay(for: endDate)
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }
}

enum CoachHRVSummarizer {
    /// One sentence describing where HRV sits against the person's own corridor,
    /// or what is still missing before that comparison means anything.
    static func line(for analysis: HRVAnalysis) -> String {
        switch analysis.state {
        case .buildingBaseline(let validNights):
            return "Sleep HRV: \(validNights) usable nights so far. A personal usual range uses "
                + "\(HRVBaselineAnalyzer.minBaselineNights) nights. No range yet."
        case .ready(let result):
            var sentence = String(
                format: "Sleep HRV: recent average %.0f ms from %d of %d nights. Personal usual range %.0f–%.0f ms.",
                result.trendMean,
                analysis.acuteNightsWithData,
                analysis.acuteWindowNights,
                result.lowerBound,
                result.upperBound
            )
            if result.isHighVariability {
                sentence += " Recent nights vary more than this person's own baseline."
            }
            return sentence
        }
    }
}
