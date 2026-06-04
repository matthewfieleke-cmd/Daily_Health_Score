import Combine
import Foundation
import SwiftData

/// SwiftUI views observe AppState's `@Published` properties, so every read/write
/// has to happen on the main thread. Marking the class `@MainActor` makes that
/// guarantee static — without it, Combine falls back to `unsafeForcedSync` when
/// a Task running off-main mutates an `@Published` property, which Xcode's
/// concurrency diagnostics flag at runtime.
@MainActor
final class AppState: ObservableObject {
    let healthKit = HealthKitService()
    let settingsStore = SettingsStore()
    let recordStore: RecordStore
    let smartGoalStore: SMARTGoalStore

    @Published var isSyncingHealth = false
    @Published var lastSyncError: String?
    @Published var healthAuthorized = false
    /// Incremented when a user-initiated refresh completes (toolbar / settings).
    @Published private(set) var userRefreshToken: UInt = 0

    init(modelContext: ModelContext) {
        recordStore = RecordStore(modelContext: modelContext)
        smartGoalStore = SMARTGoalStore(modelContext: modelContext)
    }

    func requestHealthAccess() async {
        do {
            try await healthKit.requestAuthorization()
            healthAuthorized = true
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func syncTodayFromHealth(userInitiated: Bool = false) async {
        isSyncingHealth = true
        defer { isSyncingHealth = false }
        do {
            if !healthAuthorized {
                try await healthKit.requestAuthorization()
                healthAuthorized = true
            }
            let today = DateHelpers.localDateKey()
            let existing = recordStore.records.first { $0.date == today }
            let metrics = try await healthKit.fetchMetrics(forDateKey: today)
            let record = RecordBuilder.build(
                date: today,
                metrics: DailyMetrics(
                    sleepHours: metrics.sleepHours,
                    fiberGrams: metrics.fiberGrams,
                    exerciseMinutes: metrics.exerciseMinutes
                ),
                settings: settingsStore.settings,
                settingsStore: settingsStore,
                existing: existing
            )
            recordStore.save(record)
            lastSyncError = nil
            if userInitiated {
                userRefreshToken &+= 1
            }
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    func saveManualDay(date: String, metrics: DailyMetrics) {
        let existing = recordStore.records.first { $0.date == date }
        let record = RecordBuilder.build(
            date: date,
            metrics: metrics,
            settings: settingsStore.settings,
            settingsStore: settingsStore,
            existing: existing
        )
        recordStore.save(record)
    }

    /// Refreshes today's suggestion when the day/evening phase changes (e.g. after 7:30 PM).
    func refreshTodaySuggestionForDisplayIfNeeded() {
        let todayKey = DateHelpers.localDateKey()
        guard let existing = recordStore.records.first(where: { $0.date == todayKey }) else { return }

        let phase = DayPhase.current()
        guard existing.suggestionPhase != phase else { return }

        let resolved = SuggestionResolver.resolve(
            date: todayKey,
            focus: existing.primaryFocus,
            existing: nil,
            settingsStore: settingsStore
        )

        var updated = existing
        updated.suggestion = resolved.text
        updated.suggestionPhase = resolved.phase
        updated.updatedAt = Date()
        recordStore.save(updated)
    }

    func refreshTodayAfterGoalChange() async {
        await syncTodayFromHealth(userInitiated: true)
        if lastSyncError != nil {
            applyGoalChangesToTodayRecord()
        }
    }

    private func applyGoalChangesToTodayRecord() {
        let todayKey = DateHelpers.localDateKey()
        guard let existing = recordStore.records.first(where: { $0.date == todayKey }) else { return }

        let metrics = DailyMetrics(
            sleepHours: existing.sleepHours,
            fiberGrams: existing.fiberGrams,
            exerciseMinutes: existing.exerciseMinutes
        )
        let computed = ScoreCalculator.calculate(metrics: metrics, settings: settingsStore.settings)
        let focus = ScoreCalculator.determinePrimaryFocus(computed)
        let resolved = SuggestionResolver.resolve(
            date: existing.date,
            focus: focus,
            existing: existing,
            settingsStore: settingsStore
        )

        let updated = DailyRecord(
            date: existing.date,
            sleepHours: existing.sleepHours,
            fiberGrams: existing.fiberGrams,
            exerciseMinutes: existing.exerciseMinutes,
            sleepGoal: settingsStore.settings.sleepGoal,
            fiberGoal: settingsStore.settings.fiberGoal,
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
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        recordStore.save(updated)
    }
}
