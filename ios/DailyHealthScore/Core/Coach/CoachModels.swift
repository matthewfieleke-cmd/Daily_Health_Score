import Foundation

/// Structured daily card content shown on Today.
struct DailyCoachCardContent: Equatable, Codable, Sendable {
    var acknowledgment: String
    var whyItMatters: String
    var nextStep: String
}

/// Durable preferences/constraints that INFORM the coach; never override the charter.
struct CoachUserProfile: Equatable, Codable, Sendable {
    var preferredStyle: String = ""
    var constraints: String = ""
    var nutritionNotes: String = ""
    var movementNotes: String = ""
    var sleepNotes: String = ""
    var values: String = ""
    var whatHelps: String = ""
    var whatToAvoid: String = ""

    var isEmpty: Bool {
        [
            preferredStyle, constraints, nutritionNotes, movementNotes,
            sleepNotes, values, whatHelps, whatToAvoid
        ].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var promptBlock: String {
        if isEmpty { return "No durable profile notes yet." }
        func line(_ label: String, _ value: String) -> String? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : "- \(label): \(trimmed)"
        }
        return [
            line("Preferred style", preferredStyle),
            line("Constraints", constraints),
            line("Nutrition", nutritionNotes),
            line("Movement", movementNotes),
            line("Sleep", sleepNotes),
            line("Values", values),
            line("What helps", whatHelps),
            line("What to avoid", whatToAvoid)
        ].compactMap { $0 }.joined(separator: "\n")
    }

    /// Profile notes ride along in every prompt, so each field stays short.
    static let maxFieldLength = 140

    mutating func merge(from other: CoachUserProfile) {
        func prefer(_ incoming: String, over existing: String) -> String {
            let trimmed = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return existing }
            return String(trimmed.prefix(CoachUserProfile.maxFieldLength))
        }
        preferredStyle = prefer(other.preferredStyle, over: preferredStyle)
        constraints = prefer(other.constraints, over: constraints)
        nutritionNotes = prefer(other.nutritionNotes, over: nutritionNotes)
        movementNotes = prefer(other.movementNotes, over: movementNotes)
        sleepNotes = prefer(other.sleepNotes, over: sleepNotes)
        values = prefer(other.values, over: values)
        whatHelps = prefer(other.whatHelps, over: whatHelps)
        whatToAvoid = prefer(other.whatToAvoid, over: whatToAvoid)
    }
}

struct CoachChatTurn: Identifiable, Equatable, Codable, Sendable {
    enum Role: String, Codable, Sendable {
        case user
        case coach
    }

    var id: UUID
    var role: Role
    var text: String
    var createdAt: Date

    init(id: UUID = UUID(), role: Role, text: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

/// Where a metric sits against its goal. The app computes this; the model never
/// does the arithmetic or the comparison.
enum CoachMetricLevel: String, Equatable, Sendable {
    case missing = "NO DATA"
    case below = "BELOW GOAL"
    case met = "GOAL MET"
    case exceeded = "GOAL EXCEEDED"
}

/// One fully rendered metric line, including the correct comparison sentence.
struct CoachMetricStatus: Equatable, Sendable {
    var name: String
    var level: CoachMetricLevel
    var value: Double
    var goal: Double
    var unit: String
    var points: Double
    var maxPoints: Double
    /// Model-ready sentence, e.g. "Fiber: 36.8 g of a 40 g goal — BELOW GOAL by 3.2 g (92% of goal)."
    var sentence: String

    var isAtOrAboveGoal: Bool {
        level == .met || level == .exceeded
    }
}

/// Compact facts for the model. Built by app code — never invent metrics in prompts.
struct CoachSnapshot: Equatable, Sendable {
    var todayKey: String
    var dayPhase: DayPhase
    var totalScore: Double
    var sleep: CoachMetricStatus
    var fiber: CoachMetricStatus
    var exercise: CoachMetricStatus
    var primaryFocus: PrimaryFocus
    var weekDaysWithData: Int
    var weekAvgScore: Double?
    var weekAvgSleep: Double?
    var weekAvgFiber: Double?
    var weekAvgExercise: Double?
    var fiberDaysLoggedInWeek: Int

    var metrics: [CoachMetricStatus] { [sleep, fiber, exercise] }

    /// "Tuesday, August 11, 2026" — the raw key reads like a serial number aloud.
    var todayDisplay: String { DateHelpers.formatDisplayDate(todayKey) }

    /// Goals restated verbatim so "what is my goal?" can be answered exactly.
    var goalsBlock: String {
        String(
            format: "Sleep goal %.1f h/night · Fiber goal %.0f g/day · Exercise goal %.0f min/day",
            sleep.goal,
            fiber.goal,
            exercise.goal
        )
    }

    /// Date and goals only. Used when the question is not about today's numbers,
    /// because a model that can see the metrics will steer the answer toward them.
    var minimalBlock: String {
        """
        TODAY: \(todayDisplay) (\(dayPhase.rawValue))
        USER'S GOALS: \(goalsBlock)
        Today's metric details were not requested. Do not recite or refer to them.
        """
    }

    var promptBlock: String {
        var lines: [String] = []
        lines.append("USER'S GOALS: \(goalsBlock)")
        lines.append("DATE: \(todayDisplay) (\(dayPhase.rawValue))")
        lines.append(String(format: "TODAY'S SCORE: %.1f of 10", totalScore))
        lines.append("TODAY'S METRICS (comparisons already computed — repeat them exactly):")
        for metric in metrics {
            lines.append("- \(metric.sentence)")
        }
        lines.append("WEAKEST PILLAR RIGHT NOW: \(primaryFocus.rawValue)")

        var weekly: [String] = ["7-DAY CONTEXT: \(weekDaysWithData) of 7 days have records"]
        if let weekAvgScore {
            weekly.append(String(format: "avg score %.1f", weekAvgScore))
        }
        if let weekAvgSleep {
            weekly.append(String(format: "avg sleep %.1f h", weekAvgSleep))
        }
        if let weekAvgFiber {
            weekly.append(String(format: "avg fiber %.0f g", weekAvgFiber))
        }
        if let weekAvgExercise {
            weekly.append(String(format: "avg exercise %.0f min", weekAvgExercise))
        }
        weekly.append("fiber logged on \(fiberDaysLoggedInWeek) of 7 days")
        lines.append(weekly.joined(separator: "; "))

        lines.append(
            "FACT RULES: Use only these numbers. Never claim a metric is above or below goal "
                + "unless its status line says so. Missing data means unlogged, not zero behavior."
        )
        return lines.joined(separator: "\n")
    }

    /// Coaching posture derived from goal status, so the coach never pushes "more"
    /// on a pillar that is already met.
    var coachingDirective: String {
        var directives: [String] = []
        for metric in metrics where metric.isAtOrAboveGoal {
            directives.append(
                "\(metric.name) is already at or above goal — affirm and protect it; do NOT ask for more \(metric.name.lowercased())."
            )
        }
        for metric in metrics where metric.level == .missing {
            directives.append(
                "\(metric.name) has no data today — treat as unlogged, not as failure; do not assume the behavior didn't happen."
            )
        }
        if metrics.allSatisfy({ $0.isAtOrAboveGoal }) {
            directives.append("All pillars met: shift to maintenance, recovery, or a non-scored pillar (stress, connection).")
        } else if let weakest = metrics
            .filter({ !$0.isAtOrAboveGoal && $0.level != .missing })
            .min(by: { ($0.value / max($0.goal, 0.001)) < ($1.value / max($1.goal, 0.001)) }) {
            directives.append("If offering one step, focus on \(weakest.name.lowercased()).")
        }
        return directives.isEmpty ? "No special directives." : directives.joined(separator: "\n")
    }
}

enum CoachAvailabilityStatus: Equatable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unavailable

    var title: String {
        switch self {
        case .available: return "Ready"
        case .deviceNotEligible: return "Device not eligible"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence is off"
        case .modelNotReady: return "Model getting ready"
        case .unavailable: return "Coach unavailable"
        }
    }

    var guidance: String {
        switch self {
        case .available:
            return "DHS Lifestyle Coach is ready on this device."
        case .deviceNotEligible:
            return "DHS Lifestyle Coach needs an Apple Intelligence–capable iPhone on iOS 26 or later."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to use DHS Lifestyle Coach."
        case .modelNotReady:
            return "Apple Intelligence is preparing the on-device model. Try again in a moment."
        case .unavailable:
            return "DHS Lifestyle Coach can’t run right now. Check Apple Intelligence and try again."
        }
    }
}
