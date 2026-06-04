import Foundation

/// Picks and preserves primary-focus suggestion copy for a calendar day.
@MainActor
enum SuggestionResolver {
    static func resolve(
        date: String,
        focus: PrimaryFocus,
        existing: DailyRecord?,
        settingsStore: SettingsStore,
        now: Date = Date()
    ) -> (text: String, phase: DayPhase) {
        let phase = phaseForRecord(date: date, now: now)
        if let existing,
           existing.primaryFocus == focus,
           existing.suggestionPhase == phase {
            return (existing.suggestion, phase)
        }
        let text = settingsStore.nextSuggestion(for: focus, phase: phase)
        return (text, phase)
    }

    private static func phaseForRecord(date: String, now: Date) -> DayPhase {
        if date == DateHelpers.localDateKey(from: now) {
            return DayPhase.current(from: now)
        }
        return .evening
    }
}
