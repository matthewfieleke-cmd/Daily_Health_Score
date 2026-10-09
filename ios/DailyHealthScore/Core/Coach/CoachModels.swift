import Foundation

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
    var triggers: String = ""
    var relationships: String = ""
    var recoveryNotes: String = ""
    var identityNotes: String = ""
    var stressNotes: String = ""

    var isEmpty: Bool {
        [
            preferredStyle, constraints, nutritionNotes, movementNotes,
            sleepNotes, values, whatHelps, whatToAvoid,
            triggers, relationships, recoveryNotes, identityNotes, stressNotes
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
            line("What to avoid", whatToAvoid),
            line("Triggers", triggers),
            line("Relationships", relationships),
            line("Recovery", recoveryNotes),
            line("Identity", identityNotes),
            line("Stress", stressNotes)
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
        triggers = prefer(other.triggers, over: triggers)
        relationships = prefer(other.relationships, over: relationships)
        recoveryNotes = prefer(other.recoveryNotes, over: recoveryNotes)
        identityNotes = prefer(other.identityNotes, over: identityNotes)
        stressNotes = prefer(other.stressNotes, over: stressNotes)
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
    var threadId: UUID?
    /// Which model wrote a Coach turn. Nil for user turns.
    var modelTier: CoachModelTier?
    /// Why the server model did not write this turn, when it fell to on-device.
    var fallbackReason: String? = nil
    /// JPEG file names in Coach photo storage. Empty for a text-only turn.
    var photoFileNames: [String] = []
    /// Finished-day chart attached to this turn. Nil when the reply is words only.
    var trendChart: TrendChartReference? = nil

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        createdAt: Date = Date(),
        threadId: UUID? = nil,
        modelTier: CoachModelTier? = nil,
        fallbackReason: String? = nil,
        photoFileNames: [String] = [],
        trendChart: TrendChartReference? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.threadId = threadId
        self.modelTier = modelTier
        self.fallbackReason = fallbackReason
        self.photoFileNames = photoFileNames
        self.trendChart = trendChart
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
/// One slice of today's record. A chat tool returns only the slices he names.
enum CoachTodayPart: String, CaseIterable, Sendable {
    case score, sleep, nutrition, movement, week, hrv

    static func parse(_ raw: String) -> Set<CoachTodayPart> {
        let tokens = raw.lowercased().split { !$0.isLetter && !$0.isNumber }
        var parts = Set<CoachTodayPart>()
        for token in tokens {
            switch String(token) {
            case "score", "scores": parts.insert(.score)
            case "sleep": parts.insert(.sleep)
            case "nutrition", "fiber", "food": parts.insert(.nutrition)
            case "movement", "exercise", "steps": parts.insert(.movement)
            case "week", "weeks", "average", "averages": parts.insert(.week)
            case "hrv", "variability": parts.insert(.hrv)
            case "all": return Set(CoachTodayPart.allCases)
            default: break
            }
        }
        return parts
    }
}

struct CoachSnapshot: Equatable, Sendable {
    var todayKey: String
    var dayPhase: DayPhase
    var timeOfDay: CoachTimeOfDay
    var clockLabel: String
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
    /// Precomputed HRV sentence; nil when HRV is not being tracked at all.
    var hrvSummary: String?
    /// Precomputed SMART goal lines, progress and pace already judged.
    var smartGoals: [String] = []
    /// Weight, trend, and BMI in sentences; nil when nothing was shared.
    var bodyLine: String? = nil

    var metrics: [CoachMetricStatus] { [sleep, fiber, exercise] }

    /// Which nutrition and movement the numbers were built with.
    var modeLine: String {
        let nutrition = fiber.unit == "pts"
            ? "Nutrition is Food groups, goal 4 points."
            : "Nutrition is Fiber from Apple Health, goal \(Int(fiber.goal.rounded())) g."
        let movement = exercise.unit == "steps"
            ? "Movement is Steps, goal \(MovementGoal.formatCount(exercise.goal))."
            : "Movement is Exercise Minutes, goal \(Int(exercise.goal.rounded()))."
        return "\(nutrition) \(movement)"
    }

    /// "Tuesday, August 11, 2026" — the raw key reads like a serial number aloud.
    var todayDisplay: String { DateHelpers.formatDisplayDate(todayKey) }

    /// Goals restated verbatim so "what is my goal?" can be answered exactly.
    var goalsBlock: String {
        let movementGoal = MovementGoal.formatCount(exercise.goal)
        let movement = exercise.unit == "steps"
            ? "\(exercise.name) goal \(movementGoal)/day"
            : "\(exercise.name) goal \(movementGoal) min/day"
        let nutrition = fiber.unit == "pts"
            ? "Food groups goal 4 points/day"
            : String(format: "Fiber goal %.0f g/day", fiber.goal)
        return String(format: "Sleep goal %.1f h/night · ", sleep.goal) + nutrition + " · " + movement
    }

    /// Date, clock, and the selected goals. No orders about what to say.
    var minimalBlock: String {
        """
        TODAY: \(todayDisplay)
        LOCAL CLOCK: \(clockLabel)
        USER'S GOALS: \(goalsBlock)
        """
    }

    /// Facts for the Home card. The same lines a chat tool can ask for one at a time.
    var promptBlock: String {
        var lines = [facts(for: Set(CoachTodayPart.allCases))]
        if !smartGoals.isEmpty {
            lines.append("SMART GOALS:")
            lines.append(contentsOf: smartGoals.map { "- \($0)" })
        }
        if let bodyLine {
            lines.append("BODY (shared for coaching only; never part of the score): \(bodyLine)")
        }
        return lines.joined(separator: "\n")
    }

    /// Today's numbers for a chat tool, limited to the parts he named.
    func facts(for parts: Set<CoachTodayPart>) -> String {
        var lines = ["Today, \(todayDisplay).", "Local time: \(clockLabel).", modeLine]
        if parts.contains(.score) {
            lines.append(String(format: "Score: %.1f of 10.", totalScore))
        }
        if parts.contains(.sleep) { lines.append(Self.toolFactLine(sleep)) }
        if parts.contains(.nutrition) { lines.append(Self.toolFactLine(fiber)) }
        if parts.contains(.movement) { lines.append(Self.toolFactLine(exercise)) }
        if parts.contains(.week) { lines.append(weekFact) }
        if parts.contains(.hrv) {
            lines.append(hrvSummary.map(Self.plainHRVFact) ?? "No sleep HRV nights recorded.")
        }
        return lines.joined(separator: "\n")
    }

    var toolFacts: String { facts(for: Set(CoachTodayPart.allCases)) }

    private var weekFact: String {
        var weekly = ["\(weekDaysWithData) finished days through yesterday. Today is excluded. A day with nothing logged counts as zero in these averages"]
        if let weekAvgScore {
            weekly.append(String(format: "average score %.1f (today %.1f, difference %+.1f)", weekAvgScore, totalScore, totalScore - weekAvgScore))
        }
        if let weekAvgSleep {
            weekly.append(String(format: "average sleep %.1f h (today %.1f h, difference %+.1f h)", weekAvgSleep, sleep.value, sleep.value - weekAvgSleep))
        }
        if let weekAvgFiber {
            if fiber.unit == "pts" {
                weekly.append(String(format: "average food-group score %.1f of 4 (today %.1f, difference %+.1f)", weekAvgFiber, fiber.value, fiber.value - weekAvgFiber))
            } else {
                weekly.append(String(format: "average fiber %.0f g (today %.0f g, difference %+.0f g)", weekAvgFiber, fiber.value, fiber.value - weekAvgFiber))
            }
        }
        if let weekAvgExercise {
            let noun = exercise.unit == "steps" ? "steps" : "exercise minutes"
            weekly.append(String(format: "average \(noun) %.0f (today %.0f, difference %+.0f)", weekAvgExercise, exercise.value, exercise.value - weekAvgExercise))
        }
        var line = "This week: \(weekly.joined(separator: "; "))."
        let loggedName = fiber.unit == "pts" ? "Food groups logged" : "Fiber logged"
        line += " \(loggedName) on \(fiberDaysLoggedInWeek) of \(weekDaysWithData) finished days."
        if fiber.unit == "pts" {
            line += " Apple Health fiber grams are a separate record from the food-group score."
        }
        return line
    }

    private static func toolFactLine(_ metric: CoachMetricStatus) -> String {
        let wholeNumber = metric.unit == "min" || metric.unit == "steps"
        let valueDecimals = wholeNumber ? 0 : 1
        let goalDecimals = wholeNumber || metric.goal.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1
        let valueText = String(format: "%.\(valueDecimals)f", metric.value)
        let goalText = String(format: "%.\(goalDecimals)f", metric.goal)
        if metric.level == .missing {
            return "\(metric.name): no record today. Goal \(goalText) \(metric.unit)."
        }
        return "\(metric.name): \(valueText) \(metric.unit) of a \(goalText) \(metric.unit) goal."
    }

    /// The HRV sentence without the orders appended for the Home card.
    private static func plainHRVFact(_ summary: String) -> String {
        summary
            .replacingOccurrences(of: " Do not interpret single nights.", with: "")
            .replacingOccurrences(of: " Night-to-night swings of 10–20% are normal; never diagnose from this.", with: "")
    }

    /// Date, clock, and goals as facts for chat — no scheduling rules, which
    /// belong to the Home card, not to a conversation.
    var chatContextBlock: String {
        var lines = [
            "TODAY: \(todayDisplay)",
            "LOCAL TIME: \(clockLabel)",
            "USER'S GOALS: \(goalsBlock)"
        ]
        if let bodyLine {
            lines.append("BODY (shared for coaching only; never part of the score): \(bodyLine)")
        }
        return lines.joined(separator: "\n")
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
            return "DHS Lifestyle Coach needs an Apple Intelligence–capable iPhone (iPhone 15 Pro or later) on iOS 27."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to use DHS Lifestyle Coach."
        case .modelNotReady:
            return "Apple Intelligence is preparing the on-device model. Try again in a moment."
        case .unavailable:
            return "DHS Lifestyle Coach can’t run right now. Check Apple Intelligence and try again."
        }
    }
}
