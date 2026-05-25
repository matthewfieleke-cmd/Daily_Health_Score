import Foundation

/// In-memory wizard state (not persisted until the user saves on Summary).
@MainActor
final class SMARTGoalDraft: ObservableObject, Identifiable {
    let id = UUID()

    @Published var step: SMARTWizardStep = .category
    @Published var category: SMARTGoalCategory = .sleep
    @Published var specificText: String = ""
    @Published var measurableDescription: String = ""
    @Published var measurablePattern: SMARTMeasurablePattern = .sessionsInWindow
    @Published var sessionCount: Int = 3
    @Published var dailyForSevenDays: Bool = false
    @Published var achievableText: String = ""
    @Published var relevantTheme: SMARTRelevantTheme = .health
    @Published var timePreset: SMARTTimePreset = .oneWeek
    @Published var remindersEnabled: Bool = true
    @Published var reminderHour: Int = 9
    @Published var reminderMinute: Int = 0
    @Published var reminderWeekdaysMask: Int = SMARTNotificationService.allWeekdaysMask

    var endDatePreview: Date {
        SMARTGoalLogic.endDate(preset: timePreset)
    }

    var targetCount: Int {
        let pattern = resolvedPattern()
        return SMARTGoalLogic.targetCount(pattern: pattern, sessionCount: sessionCount)
    }

    func resolvedPattern() -> SMARTMeasurablePattern {
        if dailyForSevenDays { return .dailyForSevenDays }
        if sessionCount == 1 { return .onceWithConfirm }
        return .sessionsInWindow
    }

    func applyDefaults(from settings: UserSettings, records: [DailyRecord]) {
        measurablePattern = resolvedPattern()
        measurableDescription = SMARTGoalLogic.defaultMeasurableDescription(
            category: category,
            settings: settings,
            pattern: measurablePattern,
            sessionCount: sessionCount
        )
        achievableText = SMARTGoalLogic.achievableSuggestion(
            category: category,
            records: records,
            settings: settings
        )
        if category == .relationshipBuilding {
            relevantTheme = .relationships
        } else if category == .stressManagement {
            relevantTheme = .stressManagement
        } else {
            relevantTheme = .health
        }
    }

    func buildGoal() -> SMARTGoal {
        let created = Date()
        let pattern = resolvedPattern()
        let count = SMARTGoalLogic.targetCount(pattern: pattern, sessionCount: sessionCount)
        let summary = SMARTGoalLogic.buildSummary(
            specific: specificText,
            measurable: measurableDescription,
            achievable: achievableText,
            theme: relevantTheme,
            endDate: SMARTGoalLogic.endDate(createdAt: created, preset: timePreset)
        )
        return SMARTGoal(
            id: UUID(),
            category: category,
            specificText: specificText.trimmingCharacters(in: .whitespacesAndNewlines),
            measurableDescription: measurableDescription,
            measurablePattern: pattern,
            targetCount: count,
            achievableText: achievableText,
            relevantTheme: relevantTheme,
            timePreset: timePreset,
            endDate: SMARTGoalLogic.endDate(createdAt: created, preset: timePreset),
            createdAt: created,
            generatedSummary: summary,
            filledMask: 0,
            awaitingConfirm: false,
            status: .active,
            remindersEnabled: remindersEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            reminderWeekdaysMask: reminderWeekdaysMask
        )
    }

    func summaryFields() -> [(SMARTWizardStep, String, String)] {
        [
            (.category, "Category", category.label),
            (.specific, "Specific", specificText),
            (.measurable, "Measurable", measurableDescription),
            (.achievable, "Achievable", achievableText),
            (.relevant, "Relevant", relevantTheme.label),
            (.time, "Time-bound", "\(timePreset.label) · ends \(endDatePreview.formatted(date: .abbreviated, time: .shortened))")
        ]
    }
}
