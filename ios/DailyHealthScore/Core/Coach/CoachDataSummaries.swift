import Foundation

/// Turns the parts of DHS the coach could not previously see — SMART goals and
/// HRV — into finished sentences.
///
/// Same rule as the daily metrics: every count, date difference, and pace
/// judgement is computed here so the model only has to phrase it.
enum CoachGoalSummarizer {
    /// Goals ride along in every prompt, so only the most relevant few appear.
    static let maxGoalsInPrompt = 4
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
            let lhsActive = isActive(lhs)
            let rhsActive = isActive(rhs)
            if lhsActive != rhsActive { return lhsActive }
            return lhs.endDate < rhs.endDate
        }
        return ordered.prefix(maxGoalsInPrompt).map { line(for: $0, today: today, calendar: calendar) }
    }

    private static func isActive(_ goal: SMARTGoal) -> Bool {
        goal.status == .active && !goal.isComplete && !goal.isExpired
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
            return "SMART goal \"\(name)\" (\(theme)): COMPLETE — \(progress). Celebrate it; do not assign more."
        }
        if goal.isExpired || goal.status == .ended {
            return "SMART goal \"\(name)\" (\(theme)): ENDED at \(progress). A missed goal is information, not a verdict."
        }

        let remaining = max(goal.targetCount - goal.filledCount, 0)
        let days = daysRemaining(until: goal.endDate, from: today, calendar: calendar)
        let window: String
        switch days {
        case 0: window = "ends today"
        case 1: window = "1 day left"
        default: window = "\(days) days left"
        }
        // Behind pace means more check-ins remain than days to do them in.
        let pace = remaining > days ? "BEHIND PACE" : "ON TRACK"
        return "SMART goal \"\(name)\" (\(theme)): \(progress), \(window) — \(pace) (\(remaining) to go)."
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
            return "HRV (not scored, not diagnostic): still building a personal baseline — "
                + "\(validNights) usable nights so far, \(HRVBaselineAnalyzer.minBaselineNights) needed "
                + "before a usual range means anything. Do not interpret single nights."
        case .ready(let result):
            let status: String
            switch result.status {
            case .withinRange: status = "WITHIN their usual range"
            case .belowRange: status = "BELOW their usual range"
            case .aboveRange: status = "ABOVE their usual range"
            }
            var sentence = String(
                format: "HRV (not scored, not diagnostic): recent average %.0f ms from %d of %d nights, "
                    + "against a personal usual range of %.0f–%.0f ms — %@.",
                result.trendMean,
                analysis.acuteNightsWithData,
                analysis.acuteWindowNights,
                result.lowerBound,
                result.upperBound,
                status
            )
            if result.isHighVariability {
                sentence += " Recent nights are less consistent than this person's own baseline."
            }
            sentence += " Night-to-night swings of 10–20% are normal; never diagnose from this."
            return sentence
        }
    }
}
