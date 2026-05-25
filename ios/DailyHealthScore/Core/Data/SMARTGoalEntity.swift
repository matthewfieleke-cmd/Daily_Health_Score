import Foundation
import SwiftData

@Model
final class SMARTGoalEntity {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var specificText: String
    var measurableDescription: String
    var measurablePatternRaw: String
    var targetCount: Int
    var achievableText: String
    var relevantThemeRaw: String
    var timePresetRaw: String
    var endDate: Date
    var createdAt: Date
    var generatedSummary: String
    var filledMask: Int
    var awaitingConfirm: Bool
    var statusRaw: String
    var remindersEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var reminderWeekdaysMask: Int

    init(goal: SMARTGoal) {
        id = goal.id
        categoryRaw = goal.category.rawValue
        specificText = goal.specificText
        measurableDescription = goal.measurableDescription
        measurablePatternRaw = goal.measurablePattern.rawValue
        targetCount = goal.targetCount
        achievableText = goal.achievableText
        relevantThemeRaw = goal.relevantTheme.rawValue
        timePresetRaw = goal.timePreset.rawValue
        endDate = goal.endDate
        createdAt = goal.createdAt
        generatedSummary = goal.generatedSummary
        filledMask = goal.filledMask
        awaitingConfirm = goal.awaitingConfirm
        statusRaw = goal.status.rawValue
        remindersEnabled = goal.remindersEnabled
        reminderHour = goal.reminderHour
        reminderMinute = goal.reminderMinute
        reminderWeekdaysMask = goal.reminderWeekdaysMask
    }

    func apply(_ goal: SMARTGoal) {
        categoryRaw = goal.category.rawValue
        specificText = goal.specificText
        measurableDescription = goal.measurableDescription
        measurablePatternRaw = goal.measurablePattern.rawValue
        targetCount = goal.targetCount
        achievableText = goal.achievableText
        relevantThemeRaw = goal.relevantTheme.rawValue
        timePresetRaw = goal.timePreset.rawValue
        endDate = goal.endDate
        createdAt = goal.createdAt
        generatedSummary = goal.generatedSummary
        filledMask = goal.filledMask
        awaitingConfirm = goal.awaitingConfirm
        statusRaw = goal.status.rawValue
        remindersEnabled = goal.remindersEnabled
        reminderHour = goal.reminderHour
        reminderMinute = goal.reminderMinute
        reminderWeekdaysMask = goal.reminderWeekdaysMask
    }

    func toSMARTGoal() -> SMARTGoal {
        SMARTGoal(
            id: id,
            category: SMARTGoalCategory(rawValue: categoryRaw) ?? .sleep,
            specificText: specificText,
            measurableDescription: measurableDescription,
            measurablePattern: SMARTMeasurablePattern(rawValue: measurablePatternRaw) ?? .sessionsInWindow,
            targetCount: targetCount,
            achievableText: achievableText,
            relevantTheme: SMARTRelevantTheme(rawValue: relevantThemeRaw) ?? .health,
            timePreset: SMARTTimePreset(rawValue: timePresetRaw) ?? .oneWeek,
            endDate: endDate,
            createdAt: createdAt,
            generatedSummary: generatedSummary,
            filledMask: filledMask,
            awaitingConfirm: awaitingConfirm,
            status: SMARTGoalStatus(rawValue: statusRaw) ?? .active,
            remindersEnabled: remindersEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            reminderWeekdaysMask: reminderWeekdaysMask
        )
    }
}
