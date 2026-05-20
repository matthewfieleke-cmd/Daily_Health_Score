import Foundation

enum RecordBuilder {
    static func build(
        date: String,
        metrics: DailyMetrics,
        settings: UserSettings,
        settingsStore: SettingsStore,
        now: Date = Date()
    ) -> DailyRecord {
        let computed = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        let focus = ScoreCalculator.determinePrimaryFocus(computed)
        let suggestion = settingsStore.nextSuggestion(for: focus)
        return DailyRecord(
            date: date,
            sleepHours: metrics.sleepHours,
            fiberGrams: metrics.fiberGrams,
            exerciseMinutes: metrics.exerciseMinutes,
            sleepGoal: settings.sleepGoal,
            fiberGoal: settings.fiberGoal,
            sleepScore: computed.sleepScore,
            fiberScore: computed.fiberScore,
            exerciseScore: computed.exerciseScore,
            totalScore: computed.totalScore,
            sleepPercent: computed.sleepPercent,
            fiberPercent: computed.fiberPercent,
            exercisePercent: computed.exercisePercent,
            primaryFocus: focus,
            suggestion: suggestion,
            createdAt: now,
            updatedAt: now
        )
    }
}
