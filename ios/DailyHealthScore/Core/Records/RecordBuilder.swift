import Foundation

/// Builds a scored daily record from Health metrics and settings. The Home
/// card owns coaching copy now; this no longer rotates suggestion-pool text.
@MainActor
enum RecordBuilder {
    static func build(
        date: String,
        metrics: DailyMetrics,
        settings: UserSettings,
        settingsStore: SettingsStore,
        existing: DailyRecord? = nil,
        sleepHrvSDNNMs: Double? = nil,
        now: Date = Date()
    ) -> DailyRecord {
        _ = settingsStore
        let computed = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        let focus = ScoreCalculator.determinePrimaryFocus(computed)
        return DailyRecord(
            date: date,
            sleepHours: metrics.sleepHours,
            fiberGrams: metrics.fiberGrams,
            exerciseMinutes: metrics.exerciseMinutes,
            stepCount: metrics.stepCount,
            foodGroups: metrics.foodGroups,
            sleepHrvSDNNMs: sleepHrvSDNNMs,
            sleepGoal: settings.sleepGoal,
            fiberGoal: settings.fiberGoal,
            movementGoal: settings.movementGoal,
            sleepScore: computed.sleepScore,
            fiberScore: computed.fiberScore,
            exerciseScore: computed.exerciseScore,
            totalScore: computed.totalScore,
            sleepPercent: computed.sleepPercent,
            fiberPercent: computed.fiberPercent,
            exercisePercent: computed.exercisePercent,
            primaryFocus: focus,
            suggestion: "",
            suggestionPhase: nil,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )
    }
}
