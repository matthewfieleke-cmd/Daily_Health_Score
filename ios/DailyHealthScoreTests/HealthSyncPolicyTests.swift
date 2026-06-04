import XCTest
@testable import DailyHealthScore

final class HealthSyncPolicyTests: XCTestCase {
    private let today = "2026-05-31"

    func test_alwaysPersistsToday_evenWhenAllMetricsZero() {
        let metrics = HealthDayMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 0)
        XCTAssertTrue(
            HealthSyncPolicy.shouldPersistDay(
                dateKey: today,
                todayKey: today,
                metrics: metrics,
                hasExistingRecord: false
            )
        )
    }

    func test_pastDay_withExistingRecord_isUpdatedEvenWhenZero() {
        let metrics = HealthDayMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 0)
        XCTAssertTrue(
            HealthSyncPolicy.shouldPersistDay(
                dateKey: "2026-05-30",
                todayKey: today,
                metrics: metrics,
                hasExistingRecord: true
            )
        )
    }

    func test_pastDay_withoutRecord_requiresHealthActivity() {
        let empty = HealthDayMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 0)
        XCTAssertFalse(
            HealthSyncPolicy.shouldPersistDay(
                dateKey: "2026-05-30",
                todayKey: today,
                metrics: empty,
                hasExistingRecord: false
            )
        )

        let active = HealthDayMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 10)
        XCTAssertTrue(
            HealthSyncPolicy.shouldPersistDay(
                dateKey: "2026-05-30",
                todayKey: today,
                metrics: active,
                hasExistingRecord: false
            )
        )
    }
}
