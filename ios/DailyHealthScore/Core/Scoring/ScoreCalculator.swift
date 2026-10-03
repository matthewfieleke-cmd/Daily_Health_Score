import Foundation

enum ScoreCalculator {
    static let exerciseGoalMinutes: Double = MovementGoal.exerciseMinutes.goalValue
    private static let tiePriority: [PrimaryFocus] = [.sleep, .fiber, .exercise]

    static func calculate(metrics: DailyMetrics, settings: UserSettings) -> ScoreComputation {
        let sleepGoal = settings.sleepGoal.rawValue
        let fiberGoal = Double(settings.fiberGoal.rawValue)
        let movementGoal = settings.movementGoal.goalValue
        let movementValue = settings.movementGoal.countsSteps ? metrics.stepCount : metrics.exerciseMinutes
        let sleepScore = min(metrics.sleepHours / sleepGoal, 1) * 4
        let fiberScore = min(metrics.fiberGrams / fiberGoal, 1) * 4
        let exerciseScore = movementPoints(value: movementValue, goal: movementGoal)
        let totalScore = sleepScore + fiberScore + exerciseScore
        return ScoreComputation(
            sleepScore: sleepScore,
            fiberScore: fiberScore,
            exerciseScore: exerciseScore,
            totalScore: totalScore,
            sleepPercent: metrics.sleepHours / sleepGoal,
            fiberPercent: metrics.fiberGrams / fiberGoal,
            exercisePercent: movementGoal > 0 ? movementValue / movementGoal : 0
        )
    }

    /// 2 points at the goal, linear underneath, nothing above 2.
    static func movementPoints(value: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(max(value, 0) / goal, 1) * 2
    }

    static func determinePrimaryFocus(_ scores: ScoreComputation) -> PrimaryFocus {
        if scores.sleepPercent >= 1, scores.fiberPercent >= 1, scores.exercisePercent >= 1 {
            return .maintain
        }
        let minPercent = min(scores.sleepPercent, scores.fiberPercent, scores.exercisePercent)
        let eps = 1e-9
        for focus in tiePriority {
            let value: Double
            switch focus {
            case .sleep: value = scores.sleepPercent
            case .fiber: value = scores.fiberPercent
            case .exercise: value = scores.exercisePercent
            case .maintain: continue
            }
            if abs(value - minPercent) < eps { return focus }
        }
        return .sleep
    }

    static func formatDisplayScore(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return String(format: "%.1f", rounded)
    }

    static func primaryFocusLabel(_ focus: PrimaryFocus) -> String {
        switch focus {
        case .sleep: return "Sleep"
        case .fiber: return "Fiber"
        case .exercise: return "Exercise"
        case .maintain: return "Maintain"
        }
    }
}
