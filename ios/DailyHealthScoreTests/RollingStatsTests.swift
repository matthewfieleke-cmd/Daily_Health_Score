import XCTest
@testable import DailyHealthScore

final class RollingStatsTests: XCTestCase {
    private let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)

    private func makeRecord(
        date: String,
        sleep: Double,
        fiber: Double,
        exercise: Double
    ) -> DailyRecord {
        let metrics = DailyMetrics(sleepHours: sleep, fiberGrams: fiber, exerciseMinutes: exercise)
        let computed = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        return DailyRecord(
            date: date,
            sleepHours: sleep,
            fiberGrams: fiber,
            exerciseMinutes: exercise,
            sleepGoal: settings.sleepGoal,
            fiberGoal: settings.fiberGoal,
            sleepScore: computed.sleepScore,
            fiberScore: computed.fiberScore,
            exerciseScore: computed.exerciseScore,
            totalScore: computed.totalScore,
            sleepPercent: computed.sleepPercent,
            fiberPercent: computed.fiberPercent,
            exercisePercent: computed.exercisePercent,
            primaryFocus: ScoreCalculator.determinePrimaryFocus(computed),
            suggestion: "",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func test_emptyRecords_returnsNil() {
        let stats = RollingStatsCalculator.compute(records: [], windowKeys: ["2026-05-21"])
        XCTAssertNil(stats)
    }

    func test_recordsOutsideWindow_areExcluded() {
        let records = [
            makeRecord(date: "2026-05-01", sleep: 8, fiber: 40, exercise: 30), // outside window
            makeRecord(date: "2026-05-21", sleep: 6, fiber: 30, exercise: 15),
        ]
        let stats = RollingStatsCalculator.compute(
            records: records,
            windowKeys: ["2026-05-20", "2026-05-21"]
        )
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.daysInWindow, 2)
        XCTAssertEqual(stats?.daysWithData, 1)
        XCTAssertEqual(stats?.avgSleepHours, 6, accuracy: 1e-9)
        XCTAssertEqual(stats?.avgFiberGrams, 30, accuracy: 1e-9)
        XCTAssertEqual(stats?.avgExerciseMinutes, 15, accuracy: 1e-9)
    }

    func test_multipleDays_averageAcrossOnlyDaysWithData() {
        let records = [
            makeRecord(date: "2026-05-20", sleep: 7, fiber: 30, exercise: 20),
            makeRecord(date: "2026-05-21", sleep: 8, fiber: 40, exercise: 30),
        ]
        let stats = RollingStatsCalculator.compute(
            records: records,
            windowKeys: ["2026-05-19", "2026-05-20", "2026-05-21"]
        )
        XCTAssertNotNil(stats)
        XCTAssertEqual(stats?.daysInWindow, 3)
        XCTAssertEqual(stats?.daysWithData, 2)
        XCTAssertEqual(stats?.avgSleepHours, 7.5, accuracy: 1e-9)
        XCTAssertEqual(stats?.avgFiberGrams, 35, accuracy: 1e-9)
        XCTAssertEqual(stats?.avgExerciseMinutes, 25, accuracy: 1e-9)
    }

    func test_recordsAreReturnedNewestFirst() {
        let records = [
            makeRecord(date: "2026-05-19", sleep: 5, fiber: 20, exercise: 10),
            makeRecord(date: "2026-05-21", sleep: 8, fiber: 40, exercise: 30),
            makeRecord(date: "2026-05-20", sleep: 7, fiber: 30, exercise: 20),
        ]
        let stats = RollingStatsCalculator.compute(
            records: records,
            windowKeys: ["2026-05-19", "2026-05-20", "2026-05-21"]
        )
        XCTAssertEqual(stats?.recordsInWindow.map(\.date), ["2026-05-21", "2026-05-20", "2026-05-19"])
    }

    func test_avgTotalScore_isRecomputedFromMetricsNotPersistedScore() {
        // Persist a stale total score deliberately; the rolling calculator should ignore it and
        // recompute from raw metrics so that goal-changes are reflected retroactively.
        var record = makeRecord(date: "2026-05-21", sleep: 7.5, fiber: 40, exercise: 30)
        record.totalScore = 0 // tamper
        let stats = RollingStatsCalculator.compute(records: [record], windowKeys: ["2026-05-21"])
        XCTAssertEqual(stats?.avgTotalScore, 10, accuracy: 1e-9)
    }
}
