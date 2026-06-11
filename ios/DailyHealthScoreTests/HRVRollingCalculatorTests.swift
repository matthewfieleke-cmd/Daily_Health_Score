import XCTest
@testable import DailyHealthScore

final class HRVRollingCalculatorTests: XCTestCase {
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

    func test_noData_returnsEmptySummary() {
        let summary = HRVRollingCalculator.compute(records: [], todayKey: "2026-06-09")
        XCTAssertNil(summary.averageMs)
        XCTAssertEqual(summary.nightsWithData, 0)
        XCTAssertEqual(summary.trend, .needsMoreHistory)
    }

    func test_partialWindow_showsAverageAndCount() {
        let records = [
            record(date: "2026-06-09", hrv: 40),
            record(date: "2026-06-08", hrv: 44),
            record(date: "2026-06-07", hrv: 36),
        ]
        let summary = HRVRollingCalculator.compute(records: records, todayKey: "2026-06-09")
        XCTAssertEqual(summary.averageMs, 40, accuracy: 0.001)
        XCTAssertEqual(summary.nightsWithData, 3)
        XCTAssertEqual(summary.trend, .needsMoreHistory)
    }

    func test_trendUp_whenCurrentAverageExceedsPreviousByMoreThanThreshold() {
        var records: [DailyRecord] = []
        for offset in 0 ..< 7 {
            let day = 9 - offset
            records.append(record(date: String(format: "2026-06-%02d", day), hrv: 50))
        }
        for offset in 7 ..< 14 {
            let day = 9 - offset
            records.append(record(date: String(format: "2026-06-%02d", day), hrv: 40))
        }
        let summary = HRVRollingCalculator.compute(records: records, todayKey: "2026-06-09")
        XCTAssertEqual(summary.trend, .up)
    }

    func test_trendSteady_whenDeltaWithinThreshold() {
        var records: [DailyRecord] = []
        for offset in 0 ..< 7 {
            let day = 9 - offset
            records.append(record(date: String(format: "2026-06-%02d", day), hrv: 42))
        }
        for offset in 7 ..< 14 {
            let day = 9 - offset
            records.append(record(date: String(format: "2026-06-%02d", day), hrv: 41))
        }
        let summary = HRVRollingCalculator.compute(records: records, todayKey: "2026-06-09")
        XCTAssertEqual(summary.trend, .steady)
    }
}
