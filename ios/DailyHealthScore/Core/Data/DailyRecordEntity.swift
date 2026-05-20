import Foundation
import SwiftData

@Model
final class DailyRecordEntity {
    @Attribute(.unique) var date: String
    var sleepHours: Double
    var fiberGrams: Double
    var exerciseMinutes: Double
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
    var createdAt: Date
    var updatedAt: Date

    init(record: DailyRecord) {
        date = record.date
        sleepHours = record.sleepHours
        fiberGrams = record.fiberGrams
        exerciseMinutes = record.exerciseMinutes
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
        createdAt = record.createdAt
        updatedAt = record.updatedAt
    }

    func toDailyRecord() -> DailyRecord {
        DailyRecord(
            date: date,
            sleepHours: sleepHours,
            fiberGrams: fiberGrams,
            exerciseMinutes: exerciseMinutes,
            sleepGoal: SleepGoalHours(rawValue: sleepGoalRaw) ?? .sevenHalf,
            fiberGoal: FiberGoalGrams(rawValue: fiberGoalRaw) ?? .forty,
            sleepScore: sleepScore,
            fiberScore: fiberScore,
            exerciseScore: exerciseScore,
            totalScore: totalScore,
            sleepPercent: sleepPercent,
            fiberPercent: fiberPercent,
            exercisePercent: exercisePercent,
            primaryFocus: PrimaryFocus(rawValue: primaryFocusRaw) ?? .sleep,
            suggestion: suggestion,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    func apply(_ record: DailyRecord) {
        sleepHours = record.sleepHours
        fiberGrams = record.fiberGrams
        exerciseMinutes = record.exerciseMinutes
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
        updatedAt = record.updatedAt
    }
}
