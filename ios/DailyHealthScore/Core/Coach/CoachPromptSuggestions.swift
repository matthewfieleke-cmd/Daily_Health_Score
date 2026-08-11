import Foundation

/// Opening questions offered in the chat.
///
/// A blank text field is the highest-friction moment in the whole feature: most
/// people do not know what a coach is for until they see a good question. These
/// are built from today's real numbers — the gaps are computed here, never by
/// the model — so tapping one immediately produces a specific, personal answer.
enum CoachPromptSuggestions {
    static let maximum = 4

    static func build(
        record: DailyRecord?,
        goals: [SMARTGoal] = [],
        phase: DayPhase = .current()
    ) -> [String] {
        guard let record else {
            return [
                "What should I focus on first?",
                "Why does fiber matter so much?",
                "Help me build a sleep routine"
            ]
        }

        var suggestions: [String] = []

        let fiberGap = Double(record.fiberGoal.rawValue) - record.fiberGrams
        if record.fiberGrams > 0, fiberGap > 0 {
            suggestions.append("How do I get \(Int(fiberGap.rounded())) more grams of fiber today?")
        } else if record.fiberGrams <= 0 {
            suggestions.append("What are easy ways to hit my fiber goal?")
        }

        let exerciseGap = Double(record.exerciseGoalMinutes) - record.exerciseMinutes
        if exerciseGap > 0, phase == .day {
            suggestions.append("What's a realistic way to fit in \(Int(exerciseGap.rounded())) minutes?")
        }

        if record.sleepHours > 0, record.sleepHours < record.sleepGoal.rawValue {
            suggestions.append("Why does short sleep affect me so much?")
        }

        if goals.contains(where: { $0.status == .active && !$0.isComplete && !$0.isExpired }) {
            suggestions.append("How am I doing on my SMART goals?")
        }

        if suggestions.isEmpty {
            suggestions.append("What's worth protecting tomorrow?")
        }

        suggestions.append(phase == .evening ? "Help me set up tomorrow" : "What should I eat today?")

        var seen = Set<String>()
        return suggestions.filter { seen.insert($0).inserted }.prefix(maximum).map { $0 }
    }
}
