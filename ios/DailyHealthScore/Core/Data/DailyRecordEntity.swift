import Foundation
import SwiftData

@Model
final class DailyRecordEntity {
    @Attribute(.unique) var date: String
    var sleepHours: Double
    var fiberGrams: Double
    var exerciseMinutes: Double
    /// Nil on records saved before Steps was read. Treated as 0 until the next Health sync.
    var stepCount: Double?
    /// Nil on records saved before the movement goal existed. Those days were scored on Exercise Minutes.
    var movementGoalRaw: String?
    var sleepHrvSDNNMs: Double?
    var sleepGoalRaw: Double
    var fiberGoalRaw: Int
    var sleepScore: Double
    var fiberScore: Double
    var exerciseScore: Double
    var totalScore: Double
    var sleepPercent: Double
    var fiberPercent: Double
    var exercisePercent: Double
    var primaryFocusRaw: String
    var suggestion: String
    var suggestionPhaseRaw: String?
    var createdAt: Date
    var updatedAt: Date

    init(record: DailyRecord) {
        date = record.date
        sleepHours = record.sleepHours
        fiberGrams = record.fiberGrams
        exerciseMinutes = record.exerciseMinutes
        stepCount = record.stepCount
        movementGoalRaw = record.movementGoal.rawValue
        sleepHrvSDNNMs = record.sleepHrvSDNNMs
        sleepGoalRaw = record.sleepGoal.rawValue
        fiberGoalRaw = record.fiberGoal.rawValue
        sleepScore = record.sleepScore
        fiberScore = record.fiberScore
        exerciseScore = record.exerciseScore
        totalScore = record.totalScore
        sleepPercent = record.sleepPercent
        fiberPercent = record.fiberPercent
        exercisePercent = record.exercisePercent
        primaryFocusRaw = record.primaryFocus.rawValue
        suggestion = record.suggestion
        suggestionPhaseRaw = record.suggestionPhase?.rawValue
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    func toDailyRecord() -> DailyRecord {
        DailyRecord(
            date: date,
            sleepHours: sleepHours,
            fiberGrams: fiberGrams,
            exerciseMinutes: exerciseMinutes,
            stepCount: stepCount ?? 0,
            sleepHrvSDNNMs: sleepHrvSDNNMs,
            sleepGoal: SleepGoalHours(rawValue: sleepGoalRaw) ?? .sevenHalf,
            fiberGoal: FiberGoalGrams(rawValue: fiberGoalRaw) ?? .forty,
            movementGoal: MovementGoal(rawValue: movementGoalRaw ?? "") ?? .exerciseMinutes,
            sleepScore: sleepScore,
            fiberScore: fiberScore,
            exerciseScore: exerciseScore,
            totalScore: totalScore,
            sleepPercent: sleepPercent,
            fiberPercent: fiberPercent,
            exercisePercent: exercisePercent,
            primaryFocus: PrimaryFocus(rawValue: primaryFocusRaw) ?? .sleep,
            suggestion: suggestion,
            suggestionPhase: suggestionPhaseRaw.flatMap { DayPhase(rawValue: $0) },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(_ record: DailyRecord) {
        sleepHours = record.sleepHours
        fiberGrams = record.fiberGrams
        exerciseMinutes = record.exerciseMinutes
        stepCount = record.stepCount
        movementGoalRaw = record.movementGoal.rawValue
        sleepHrvSDNNMs = record.sleepHrvSDNNMs
        sleepGoalRaw = record.sleepGoal.rawValue
        fiberGoalRaw = record.fiberGoal.rawValue
        sleepScore = record.sleepScore
        fiberScore = record.fiberScore
        exerciseScore = record.exerciseScore
        totalScore = record.totalScore
        sleepPercent = record.sleepPercent
        fiberPercent = record.fiberPercent
        exercisePercent = record.exercisePercent
        primaryFocusRaw = record.primaryFocus.rawValue
        suggestion = record.suggestion
        suggestionPhaseRaw = record.suggestionPhase?.rawValue
        updatedAt = record.updatedAt
    }
}
