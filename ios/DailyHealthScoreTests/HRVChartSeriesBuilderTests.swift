import XCTest
@testable import DailyHealthScore

final class HRVChartSeriesBuilderTests: XCTestCase {
    private func record(date: String, hrv: Double?) -> DailyRecord {
        DailyRecord(
            date: date,
            sleepHours: 7,
            fiberGrams: 30,
            exerciseMinutes: 30,
            sleepHrvSDNNMs: hrv,
            sleepGoal: .sevenHalf,
            fiberGoal: .forty,
            sleepScore: 3,
            fiberScore: 3,
            exerciseScore: 2,
            totalScore: 8,
            sleepPercent: 1,
            fiberPercent: 1,
            exercisePercent: 1,
            primaryFocus: .maintain,
            suggestion: "",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func test_build_includesOnlyNightsWithHRVInWindow() {
        let records = [
            record(date: "2026-06-12", hrv: 40),
            record(date: "2026-06-11", hrv: nil),
            record(date: "2026-06-10", hrv: 36),
            record(date: "2026-06-01", hrv: 99),
        ]

        let series = HRVChartSeriesBuilder.build(
            records: records,
            todayKey: "2026-06-12",
            days: 7
        )

        XCTAssertEqual(series.points.map(\.dateKey), ["2026-06-10", "2026-06-12"])
        XCTAssertEqual(series.averageMs, 38, accuracy: 0.001)
    }

    func test_build_emptyWhenNoHRVInWindow() {
        let records = [
            record(date: "2026-06-12", hrv: nil),
            record(date: "2026-06-11", hrv: nil),
        ]

        let series = HRVChartSeriesBuilder.build(
            records: records,
            todayKey: "2026-06-12",
            days: 30
        )

        XCTAssertTrue(series.points.isEmpty)
        XCTAssertNil(series.averageMs)
    }
}
