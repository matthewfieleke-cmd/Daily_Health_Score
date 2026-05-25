import Foundation
import SwiftData

@Model
final class SMARTGoalEntity {
    @Attribute(.unique) var id: UUID
    var specificText: String
    var targetCount: Int
    var relevantThemeRaw: String
    var timeWindowDays: Int
    var endDate: Date
    var createdAt: Date
    var generatedSummary: String
    var filledMask: Int
    var statusRaw: String
    var remindersEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var reminderWeekdaysMask: Int

    init(goal: SMARTGoal) {
        id = goal.id
        specificText = goal.specificText
        targetCount = goal.targetCount
        relevantThemeRaw = goal.relevantTheme.rawValue
        timeWindowDays = goal.timeWindowDays
        endDate = goal.endDate
        createdAt = goal.createdAt
        generatedSummary = goal.generatedSummary
        filledMask = goal.filledMask
        statusRaw = goal.status.rawValue
        remindersEnabled = goal.remindersEnabled
        reminderHour = goal.reminderHour
        reminderMinute = goal.reminderMinute
        reminderWeekdaysMask = goal.reminderWeekdaysMask
    }

    func apply(_ goal: SMARTGoal) {
        specificText = goal.specificText
        targetCount = goal.targetCount
        relevantThemeRaw = goal.relevantTheme.rawValue
        timeWindowDays = goal.timeWindowDays
        endDate = goal.endDate
        createdAt = goal.createdAt
        generatedSummary = goal.generatedSummary
        filledMask = goal.filledMask
        statusRaw = goal.status.rawValue
        remindersEnabled = goal.remindersEnabled
        reminderHour = goal.reminderHour
        reminderMinute = goal.reminderMinute
        reminderWeekdaysMask = goal.reminderWeekdaysMask
    }

    func toSMARTGoal() -> SMARTGoal {
        SMARTGoal(
            id: id,
            specificText: specificText,
            targetCount: targetCount,
            relevantTheme: SMARTRelevantTheme(rawValue: relevantThemeRaw) ?? .health,
            timeWindowDays: timeWindowDays,
            endDate: endDate,
            createdAt: createdAt,
            generatedSummary: generatedSummary,
            filledMask: filledMask,
            status: SMARTGoalStatus(rawValue: statusRaw) ?? .active,
            remindersEnabled: remindersEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            reminderWeekdaysMask: reminderWeekdaysMask
        )
    }
}
