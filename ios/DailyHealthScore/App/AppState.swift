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

    @Published var isSyncingHealth = false
    @Published var lastSyncError: String?
    @Published var healthAuthorized = false
    /// Incremented when a user-initiated refresh completes (toolbar / settings).
    @Published private(set) var userRefreshToken: UInt = 0

    init(modelContext: ModelContext) {
        recordStore = RecordStore(modelContext: modelContext)
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
            let metrics = try await healthKit.fetchMetrics(forDateKey: today)
            let record = RecordBuilder.build(
                date: today,
                metrics: DailyMetrics(
                    sleepHours: metrics.sleepHours,
                    fiberGrams: metrics.fiberGrams,
                    exerciseMinutes: metrics.exerciseMinutes
                ),
                settings: settingsStore.settings,
                settingsStore: settingsStore
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
        let record = RecordBuilder.build(
            date: date,
            metrics: metrics,
            settings: settingsStore.settings,
            settingsStore: settingsStore
        )
        recordStore.save(record)
    }
}
