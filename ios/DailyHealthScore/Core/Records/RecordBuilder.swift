import Foundation

/// `@MainActor` because `build` calls `SettingsStore.nextSuggestion(for:phase:)` to
/// advance the rotating suggestion text, and `SettingsStore` is itself
/// MainActor-isolated. The only call sites of `build` are on `AppState`, which
/// is also MainActor, so the constraint costs us nothing.
@MainActor
enum RecordBuilder {
    static func build(
        date: String,
        metrics: DailyMetrics,
        settings: UserSettings,
        settingsStore: SettingsStore,
        existing: DailyRecord? = nil,
        now: Date = Date()
    ) -> DailyRecord {
        let computed = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        let focus = ScoreCalculator.determinePrimaryFocus(computed)
        let resolved = SuggestionResolver.resolve(
            date: date,
            focus: focus,
            existing: existing?.date == date ? existing : nil,
            settingsStore: settingsStore,
            now: now
        )
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
            suggestion: resolved.text,
            suggestionPhase: resolved.phase,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )
    }
}
