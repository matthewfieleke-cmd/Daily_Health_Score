import Combine
import Foundation
import SwiftData

final class AppState: ObservableObject {
    let healthKit = HealthKitService()
    let settingsStore = SettingsStore()
    let recordStore: RecordStore

    @Published var isSyncingHealth = false
    @Published var lastSyncError: String?
    @Published var healthAuthorized = false

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

    func syncTodayFromHealth() async {
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
