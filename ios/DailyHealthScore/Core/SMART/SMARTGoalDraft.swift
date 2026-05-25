import Foundation

/// In-memory wizard state (not persisted until the user saves on Summary).
@MainActor
final class SMARTGoalDraft: ObservableObject, Identifiable {
    let id = UUID()

    @Published var step: SMARTWizardStep = .specific
    @Published var specificText: String = ""
    @Published var targetCount: Int = 3
    @Published var relevantTheme: SMARTRelevantTheme = .health
    @Published var timeWindowDays: Int = 7
    @Published var remindersEnabled: Bool = true
    @Published var reminderHour: Int = 9
    @Published var reminderMinute: Int = 0
    @Published var reminderWeekdaysMask: Int = SMARTNotificationService.allWeekdaysMask

    var endDatePreview: Date {
        SMARTGoalLogic.endDate(days: timeWindowDays)
    }

    var generatedSummaryPreview: String {
        SMARTGoalLogic.buildSummary(
            specific: specificText,
            targetCount: SMARTGoalLogic.clampedTargetCount(targetCount),
            theme: relevantTheme,
            timeWindowDays: SMARTGoalLogic.clampedDays(timeWindowDays),
            endDate: endDatePreview
        )
    }

    func buildGoal() -> SMARTGoal {
        let created = Date()
        let count = SMARTGoalLogic.clampedTargetCount(targetCount)
        let days = SMARTGoalLogic.clampedDays(timeWindowDays)
        let endDate = SMARTGoalLogic.endDate(createdAt: created, days: days)
        let summary = SMARTGoalLogic.buildSummary(
            specific: specificText,
            targetCount: count,
            theme: relevantTheme,
            timeWindowDays: days,
            endDate: endDate
        )
        return SMARTGoal(
            id: UUID(),
            specificText: specificText.trimmingCharacters(in: .whitespacesAndNewlines),
            targetCount: count,
            relevantTheme: relevantTheme,
            timeWindowDays: days,
            endDate: endDate,
            createdAt: created,
            generatedSummary: summary,
            filledMask: 0,
            status: .active,
            remindersEnabled: remindersEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            reminderWeekdaysMask: reminderWeekdaysMask
        )
    }

    func summaryFields() -> [(SMARTWizardStep, String, String)] {
        let count = SMARTGoalLogic.clampedTargetCount(targetCount)
        let days = SMARTGoalLogic.clampedDays(timeWindowDays)
        [
            (SMARTWizardStep.specific, "Specific", specificText),
            (SMARTWizardStep.measurable, "Measurable", "\(count) \(count == 1 ? "time" : "times")"),
            (SMARTWizardStep.achievable, "Achievable", SMARTGoalLogic.achievableReminder),
            (SMARTWizardStep.relevant, "Relevant", relevantTheme.label),
            (SMARTWizardStep.time, "Time-bound", "\(days) \(days == 1 ? "day" : "days") · ends \(endDatePreview.formatted(date: .abbreviated, time: .shortened))")
        ]
    }
}
