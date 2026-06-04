import Foundation

/// Rules for which calendar days get a stored `DailyRecord` during Health backfill.
enum HealthSyncPolicy {
    /// Today is always stored (zeros allowed). Past days are stored when a record
    /// already exists or Health reports any activity for that day.
    static func shouldPersistDay(
        dateKey: String,
        todayKey: String,
        metrics: HealthDayMetrics,
        hasExistingRecord: Bool
    ) -> Bool {
        if dateKey == todayKey { return true }
        if hasExistingRecord { return true }
        return metrics.sleepHours > 0 || metrics.fiberGrams > 0 || metrics.exerciseMinutes > 0
    }
}
