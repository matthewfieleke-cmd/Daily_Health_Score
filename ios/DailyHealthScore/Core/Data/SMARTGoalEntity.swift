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
    var personalReason: String = ""
    var cue: String = ""
    var expectedBarriers: String = ""
    var fallbackAction: String = ""
    var confidence: Int = 0
    var followThroughEnabled: Bool = false
    var reflectionHour: Int = 20
    var reflectionMinute: Int = 0

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
        applyPlan(goal.plan)
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
        applyPlan(goal.plan)
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
            reminderWeekdaysMask: reminderWeekdaysMask,
            plan: SMARTGoalPlan(
                personalReason: personalReason,
                cue: cue,
                expectedBarriers: expectedBarriers,
                fallbackAction: fallbackAction,
                confidence: confidence > 0 ? confidence : nil,
                followThroughEnabled: followThroughEnabled,
                reflectionHour: reflectionHour,
                reflectionMinute: reflectionMinute
            )
        )
    }

    private func applyPlan(_ plan: SMARTGoalPlan) {
        personalReason = plan.personalReason
        cue = plan.cue
        expectedBarriers = plan.expectedBarriers
        fallbackAction = plan.fallbackAction
        confidence = plan.confidence ?? 0
        followThroughEnabled = plan.followThroughEnabled
        reflectionHour = plan.reflectionHour
        reflectionMinute = plan.reflectionMinute
    }
}
