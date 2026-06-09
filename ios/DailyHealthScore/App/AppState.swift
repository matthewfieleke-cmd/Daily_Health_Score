import Combine
import Foundation
import SwiftData

/// SwiftUI views observe AppState's `@Published` properties, so every read/write
/// has to happen on the main thread. Marking the class `@MainActor` makes that
/// guarantee static — without it, Combine falls back to `unsafeForcedSync` when
/// a Task running off-main mutates an `@Published` property, which Xcode's
/// concurrency diagnostics flag at runtime.
enum HealthSyncBannerPhase: Equatable {
    case hidden
    case syncing
    case complete
}

@MainActor
final class AppState: ObservableObject {
    private enum SyncBannerTiming {
        static let minimumSyncingDuration: TimeInterval = 1.5
        static let completeDuration: TimeInterval = 1
    }

    let healthKit = HealthKitService()
    let settingsStore = SettingsStore()
    let recordStore: RecordStore
    let smartGoalStore: SMARTGoalStore

    @Published var healthSyncBannerPhase: HealthSyncBannerPhase = .hidden
    /// True while sync work runs and through the minimum syncing-banner display window.
    @Published var isSyncingHealth = false
    @Published var lastSyncError: String?
    @Published var healthAuthorized = false
    /// Incremented when a user-initiated refresh completes (toolbar / settings).
    @Published private(set) var userRefreshToken: UInt = 0

    private var activeSyncGeneration: UInt = 0

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

    /// Syncs today and backfills/updates stored days in the retention window from Apple Health.
    func syncTodayFromHealth(userInitiated: Bool = false) async {
        activeSyncGeneration &+= 1
        let generation = activeSyncGeneration
        let syncStartedAt = Date()

        healthSyncBannerPhase = .syncing
        isSyncingHealth = true

        var succeeded = false
        do {
            if !healthAuthorized {
                try await healthKit.requestAuthorization()
                healthAuthorized = true
            }

            let today = DateHelpers.localDateKey()
            let windowKeys = DateHelpers.rollingDateKeys(days: DateHelpers.retentionDays)
            var existingByDate = Dictionary(
                uniqueKeysWithValues: recordStore.records.map { ($0.date, $0) }
            )

            // Today always gets a record, even if every Health read is empty or
            // fails — a partial day still shows a score (0 for missing metrics).
            let todayRecord = await buildTodayRecord(
                today: today,
                existing: existingByDate[today]
            )
            recordStore.save(todayRecord)
            existingByDate[today] = todayRecord

            // Backfill never aborts because of an individual day; failures simply
            // skip that day and the rest of the window still updates.
            var backfillBatch: [DailyRecord] = []
            for dateKey in windowKeys where dateKey != today {
                guard let record = await buildRecordIfNeeded(
                    dateKey: dateKey,
                    todayKey: today,
                    existingByDate: existingByDate
                ) else { continue }
                backfillBatch.append(record)
                existingByDate[dateKey] = record
            }
            recordStore.saveBatch(backfillBatch)
            lastSyncError = nil
            succeeded = true
            if userInitiated {
                userRefreshToken &+= 1
            }
        } catch {
            lastSyncError = error.localizedDescription
        }

        await waitForMinimumSyncingBannerDuration(since: syncStartedAt)
        guard generation == activeSyncGeneration else { return }

        healthSyncBannerPhase = .hidden
        isSyncingHealth = false

        guard succeeded else { return }

        healthSyncBannerPhase = .complete
        try? await Task.sleep(for: .seconds(SyncBannerTiming.completeDuration))
        guard generation == activeSyncGeneration else { return }
        healthSyncBannerPhase = .hidden
    }

    private func waitForMinimumSyncingBannerDuration(since start: Date) async {
        let elapsed = Date().timeIntervalSince(start)
        let remaining = SyncBannerTiming.minimumSyncingDuration - elapsed
        guard remaining > 0 else { return }
        try? await Task.sleep(for: .seconds(remaining))
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

    /// Builds today's record using whatever Health data is available; `fetchMetrics`
    /// already resolves missing metrics to 0, so this only falls back to all-zeros
    /// if Health is unavailable entirely.
    private func buildTodayRecord(today: String, existing: DailyRecord?) async -> DailyRecord {
        let healthMetrics = (try? await healthKit.fetchMetrics(forDateKey: today))
            ?? HealthDayMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 0)
        return RecordBuilder.build(
            date: today,
            metrics: DailyMetrics(
                sleepHours: healthMetrics.sleepHours,
                fiberGrams: healthMetrics.fiberGrams,
                exerciseMinutes: healthMetrics.exerciseMinutes
            ),
            settings: settingsStore.settings,
            settingsStore: settingsStore,
            existing: existing
        )
    }

    private func buildRecordIfNeeded(
        dateKey: String,
        todayKey: String,
        existingByDate: [String: DailyRecord]
    ) async -> DailyRecord? {
        do {
            let healthMetrics = try await healthKit.fetchMetrics(forDateKey: dateKey)
            let existing = existingByDate[dateKey]
            guard HealthSyncPolicy.shouldPersistDay(
                dateKey: dateKey,
                todayKey: todayKey,
                metrics: healthMetrics,
                hasExistingRecord: existing != nil
            ) else {
                return nil
            }
            return RecordBuilder.build(
                date: dateKey,
                metrics: DailyMetrics(
                    sleepHours: healthMetrics.sleepHours,
                    fiberGrams: healthMetrics.fiberGrams,
                    exerciseMinutes: healthMetrics.exerciseMinutes
                ),
                settings: settingsStore.settings,
                settingsStore: settingsStore,
                existing: existing
            )
        } catch {
            return nil
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
