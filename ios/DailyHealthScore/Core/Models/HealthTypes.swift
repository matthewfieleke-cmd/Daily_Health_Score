import Foundation

enum PrimaryFocus: String, Codable, CaseIterable {
    case sleep, fiber, exercise, maintain
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

    static let `default` = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)
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
}

struct DailyRecord: Identifiable, Equatable, Codable {
    var id: String { date }
    var date: String
    var sleepHours: Double
    var fiberGrams: Double
    var exerciseMinutes: Double
    var sleepGoal: SleepGoalHours
    var fiberGoal: FiberGoalGrams
    let exerciseGoalMinutes: Int = 30
    var sleepScore: Double
    var fiberScore: Double
    var exerciseScore: Double
    var totalScore: Double
    var sleepPercent: Double
    var fiberPercent: Double
    var exercisePercent: Double
    var primaryFocus: PrimaryFocus
    var suggestion: String
    var createdAt: Date
    var updatedAt: Date
}
