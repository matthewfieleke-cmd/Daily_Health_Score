import Foundation

enum PrimaryFocus: String, Codable, CaseIterable {
    case sleep, fiber, exercise, maintain
}

/// The 2-point movement goal. Exercise Minutes and Steps are both read from
/// Apple Health; only the selected goal is scored.
enum MovementGoal: String, Codable, CaseIterable, Identifiable {
    case exerciseMinutes
    case steps8000
    case steps10000

    var id: String { rawValue }

    var countsSteps: Bool {
        switch self {
        case .exerciseMinutes: return false
        case .steps8000, .steps10000: return true
        }
    }

    var goalValue: Double {
        switch self {
        case .exerciseMinutes: return 30
        case .steps8000: return 8_000
        case .steps10000: return 10_000
        }
    }

    /// Apple Health's name for this measurement.
    var metricName: String {
        countsSteps ? "Steps" : "Exercise Minutes"
    }

    var unit: String {
        countsSteps ? "steps" : "min"
    }

    var systemImage: String {
        countsSteps ? "figure.walk" : "figure.run"
    }

    /// Settings row. The number distinguishes the two Steps goals.
    var settingsLabel: String {
        switch self {
        case .exerciseMinutes: return "30 Exercise Minutes"
        case .steps8000: return "8,000 Steps"
        case .steps10000: return "10,000 Steps"
        }
    }

    static func formatCount(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return countFormatter.string(from: NSNumber(value: rounded)) ?? "\(rounded)"
    }

    private static let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

enum SleepGoalHours: Double, CaseIterable, Identifiable, Codable {
    case seven = 7
    case sevenHalf = 7.5
    case eight = 8

    var id: Double { rawValue }

    var label: String {
        switch self {
        case .seven: return "7"
        case .sevenHalf: return "7.5"
        case .eight: return "8"
        }
    }
}

enum FiberGoalGrams: Int, CaseIterable, Identifiable, Codable {
    case thirty = 30
    case forty = 40
    case fifty = 50

    var id: Int { rawValue }
}

struct UserSettings: Equatable {
    var sleepGoal: SleepGoalHours
    var fiberGoal: FiberGoalGrams
    var movementGoal: MovementGoal = .exerciseMinutes
    var nutritionMode: NutritionMode = .fiber

    static let fiberGoalGrams = 40.0
    static let `default` = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)

    /// The nutrition and movement settings selected now, as a fact.
    var coachModeLine: String {
        let nutrition: String
        switch nutritionMode {
        case .fiber:
            nutrition = "Nutrition is Fiber from Apple Health, goal 40 g."
        case .foodGroups:
            nutrition = "Nutrition is Food groups, logged in the app, goal 4 points."
        }
        let movement: String
        switch movementGoal {
        case .exerciseMinutes:
            movement = "Movement is Exercise Minutes, goal 30."
        case .steps8000:
            movement = "Movement is Steps, goal 8,000."
        case .steps10000:
            movement = "Movement is Steps, goal 10,000."
        }
        return "\(nutrition) \(movement)"
    }
}

struct ScoreComputation: Equatable {
    var sleepScore: Double
    var fiberScore: Double
    var exerciseScore: Double
    var totalScore: Double
    var sleepPercent: Double
    var fiberPercent: Double
    var exercisePercent: Double
}

struct DailyMetrics: Equatable {
    var sleepHours: Double
    var fiberGrams: Double
    var exerciseMinutes: Double
    var stepCount: Double = 0
    var foodGroups: FoodGroupServings = .empty

    /// Health sync replaces sleep, grams, steps, and exercise minutes.
    /// The food-group log on an existing day stays.
    func keepingFoodGroups(from existing: DailyRecord?) -> DailyMetrics {
        guard let existing else { return self }
        var copy = self
        copy.foodGroups = existing.foodGroups
        return copy
    }
}

struct DailyRecord: Identifiable, Equatable, Codable {
    var id: String { date }
    var date: String
    var sleepHours: Double
    var fiberGrams: Double
    var exerciseMinutes: Double
    /// Apple Health step count for the calendar day. Scored only when the movement goal is Steps.
    var stepCount: Double = 0
    /// Manual food-group log. Empty and unlogged until the person saves the sheet.
    var foodGroups: FoodGroupServings = .empty
    /// Average SDNN (ms) from HRV readings during attributed sleep; not part of the score.
    var sleepHrvSDNNMs: Double? = nil
    var sleepGoal: SleepGoalHours
    var fiberGoal: FiberGoalGrams
    /// Which 2-point goal this day was scored with.
    var movementGoal: MovementGoal = .exerciseMinutes
    // `var` (not `let`) so `Codable` decoding can override the default value.
    // Kept so older exports still decode. Scoring uses `movementGoal`.
    var exerciseGoalMinutes: Int = 30
    var sleepScore: Double
    var fiberScore: Double
    var exerciseScore: Double
    var totalScore: Double
    var sleepPercent: Double
    var fiberPercent: Double
    var exercisePercent: Double
    var primaryFocus: PrimaryFocus
    var suggestion: String
    /// Which day/evening pool produced `suggestion`; nil on older records until refreshed.
    var suggestionPhase: DayPhase? = nil
    var createdAt: Date
    var updatedAt: Date

    /// The number that earned the movement points: steps or exercise minutes.
    var movementValue: Double {
        movementGoal.countsSteps ? stepCount : exerciseMinutes
    }
}
