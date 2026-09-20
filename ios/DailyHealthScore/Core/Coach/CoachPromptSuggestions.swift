import Foundation

/// Opening questions offered in the chat.
///
/// A blank text field is the highest-friction moment in the whole feature: most
/// people do not know what a coach is for until they see a good question. The
/// chips set the tone for what the Coach is for, so they are varied on purpose:
/// something about the person's day, something about a plan or a person,
/// something to learn, help with words — and at most one question about the
/// numbers. The metric gap, when shown, is computed here, never by the model.
enum CoachPromptSuggestions {
    static let maximum = 4

    static func build(
        record: DailyRecord?,
        goals: [SMARTGoal] = [],
        phase: DayPhase = .current(),
        focus: CoachFocusContext? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [String] {
        guard let record else {
            return [
                "What should I focus on first?",
                "Why does fiber matter so much?",
                "Help me build a sleep routine"
            ]
        }

        // Rotation: the day of the year moves through each pool; the caller's
        // phase separates a morning open from an evening one.
        let dayIndex = calendar.ordinality(of: .day, in: .year, for: now) ?? 0
        let evening = phase == .evening

        var suggestions: [String] = []

        // A chat opened from a metric card leads with that metric.
        switch focus?.feature {
        case .sleep?:
            suggestions.append("What does last night's sleep mean for today?")
        case .fiber?:
            suggestions.append("What's the easiest fiber I can add today?")
        case .exercise?:
            suggestions.append(evening ? "How should I plan tomorrow's movement?" : "Where does movement fit today?")
        default:
            break
        }

        if evening {
            suggestions.append("Help me set up tomorrow")
        }
        suggestions.append(pick(evening ? reflectiveEvening : reflectiveMorning, dayIndex))

        // One slot rotates across people and plans, learning, and writing help.
        switch dayIndex % 3 {
        case 0: suggestions.append(pick(peopleAndPlans, dayIndex))
        case 1: suggestions.append(pick(learning, dayIndex))
        default: suggestions.append("Help me word a message I've been putting off")
        }

        let hasLiveGoal = goals.contains { $0.status == .active && !$0.isComplete && !$0.isExpired }
        if hasLiveGoal {
            suggestions.append("How am I doing on my SMART goals?")
        } else if dayIndex % 2 == 0 {
            suggestions.append("Help me set a small goal for this week")
        }

        // One question about the numbers at most, the most useful one today.
        if focus == nil, let metric = metricQuestion(record: record, evening: evening) {
            suggestions.append(metric)
        }

        var seen = Set<String>()
        return suggestions.filter { seen.insert($0).inserted }.prefix(maximum).map { $0 }
    }

    /// The single most useful numbers question for the day, or nil when the day
    /// is in hand. Gaps are computed here.
    static func metricQuestion(record: DailyRecord, evening: Bool) -> String? {
        let fiberGap = Double(record.fiberGoal.rawValue) - record.fiberGrams
        if record.fiberGrams <= 0 {
            return "What are easy ways to hit my fiber goal?"
        }
        if fiberGap > 0, !evening {
            return "How do I get \(Int(fiberGap.rounded())) more grams of fiber today?"
        }
        let exerciseGap = Double(record.exerciseGoalMinutes) - record.exerciseMinutes
        if exerciseGap > 0, !evening {
            return "What's a realistic way to fit in \(Int(exerciseGap.rounded())) minutes?"
        }
        if record.sleepHours > 0, record.sleepHours < record.sleepGoal.rawValue {
            return "Why does short sleep affect me so much?"
        }
        return nil
    }

    private static func pick(_ pool: [String], _ index: Int) -> String {
        pool[index % pool.count]
    }

    static let reflectiveMorning = [
        "What's one thing worth protecting today?",
        "What would make today a good day when I look back tonight?",
        "Where will today get hard, and what would make it easier?",
        "I need a five-minute reset — what works?"
    ]

    static let reflectiveEvening = [
        "What went better today than the numbers show?",
        "What got in the way today?",
        "Help me wind down tonight",
        "What did I do today that I'll be glad about tomorrow?"
    ]

    static let peopleAndPlans = [
        "Help me plan something with my family this week",
        "How do I bring up something hard with someone I love?",
        "I want to be more present at home in the evenings",
        "Help me think through something at work"
    ]

    static let learning = [
        "How does a walk outside help beyond the steps?",
        "What does alcohol do to sleep?",
        "Why does stress make me reach for food?",
        "How much protein do I actually need?",
        "What actually helps me fall asleep faster?",
        "Is there good evidence for intermittent fasting?"
    ]
}
