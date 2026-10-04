import XCTest
@testable import DailyHealthScore

final class CompletedTrendTests: XCTestCase {
    private let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)
    private var calendar: Calendar { .current }

    private func now() -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 12))!
    }

    private func record(
        _ date: String,
        sleep: Double = 0,
        fiber: Double = 0,
        minutes: Double = 0,
        steps: Double = 0
    ) -> DailyRecord {
        let goal = settings
        let metrics = DailyMetrics(
            sleepHours: sleep,
            fiberGrams: fiber,
            exerciseMinutes: minutes,
            stepCount: steps
        )
        let computed = ScoreCalculator.calculate(metrics: metrics, settings: goal)
        return DailyRecord(
            date: date,
            sleepHours: sleep,
            fiberGrams: fiber,
            exerciseMinutes: minutes,
            stepCount: steps,
            sleepGoal: goal.sleepGoal,
            fiberGoal: goal.fiberGoal,
            movementGoal: goal.movementGoal,
            sleepScore: computed.sleepScore,
            fiberScore: computed.fiberScore,
            exerciseScore: computed.exerciseScore,
            totalScore: computed.totalScore,
            sleepPercent: computed.sleepPercent,
            fiberPercent: computed.fiberPercent,
            exercisePercent: computed.exercisePercent,
            primaryFocus: .sleep,
            suggestion: "",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func test_excludesTodayAndCountsAMissingDayAsZero() throws {
        let records = [
            record("2026-10-03", sleep: 9),
            record("2026-10-02", sleep: 8),
            record("2026-09-30", sleep: 6),
            record("2026-09-26", sleep: 7),
        ]
        let trend = CompletedTrendBuilder.build(
            metric: .sleep,
            records: records,
            settings: settings,
            now: now(),
            calendar: calendar
        )
        let bars = try XCTUnwrap(trend).bars
        XCTAssertEqual(bars.map(\.dateKey), [
            "2026-09-26", "2026-09-27", "2026-09-28", "2026-09-29",
            "2026-09-30", "2026-10-01", "2026-10-02",
        ])
        XCTAssertFalse(bars.contains { $0.dateKey == "2026-10-03" })
        XCTAssertEqual(bars.first { $0.dateKey == "2026-09-27" }?.value, 0)
        XCTAssertEqual(trend?.average ?? -1, (7 + 0 + 0 + 0 + 6 + 0 + 8) / 7, accuracy: 1e-9)
        XCTAssertEqual(trend?.blankDays, 4)
        XCTAssertTrue(trend?.caption.contains("count as zero") ?? false)
        XCTAssertTrue(trend?.caption.contains("not included") ?? false)
    }

    func test_partialHistoryDoesNotInventDaysBeforeTheFirstRecord() {
        let records = [
            record("2026-10-02", sleep: 8, fiber: 40),
            record("2026-10-01", sleep: 6, fiber: 0),
        ]
        let trend = CompletedTrendBuilder.build(
            metric: .sleep,
            records: records,
            settings: settings,
            now: now(),
            calendar: calendar
        )
        XCTAssertEqual(trend?.bars.map(\.dateKey), ["2026-10-01", "2026-10-02"])
        XCTAssertEqual(trend?.isPartial, true)
        XCTAssertEqual(trend?.average ?? -1, 7, accuracy: 1e-9)
        XCTAssertTrue(trend?.caption.contains("2 completed days so far") ?? false)
        XCTAssertEqual(trend?.thirty?.isPartial, true)
        XCTAssertEqual(trend?.thirty?.dayCount, 2)
    }

    func test_todayAloneCannotChart() {
        let trend = CompletedTrendBuilder.build(
            metric: .fiber,
            records: [record("2026-10-03", fiber: 40)],
            settings: settings,
            now: now(),
            calendar: calendar
        )
        XCTAssertNil(trend)
    }

    func test_stepsUseTheSelectedGoalAndIgnoreExerciseMinutes() {
        let steps = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty, movementGoal: .steps8000)
        let records = [
            record("2026-10-02", minutes: 30, steps: 4_000),
            record("2026-10-01", minutes: 0, steps: 2_000),
        ]
        let trend = CompletedTrendBuilder.build(
            metric: .movement,
            records: records,
            settings: steps,
            now: now(),
            calendar: calendar
        )
        XCTAssertEqual(trend?.title, "Steps")
        XCTAssertEqual(trend?.goal, 8_000)
        XCTAssertEqual(trend?.average ?? -1, 3_000, accuracy: 1e-9)
        XCTAssertEqual(trend?.headline, "3,000 steps")
    }

    func test_sleepHeadlineUsesHoursAndMinutes() {
        XCTAssertEqual(CompletedTrendBuilder.formatSleep(6.5666), "6 hr 34 min")
        XCTAssertEqual(CompletedTrendBuilder.formatSleep(7.5), "7 hr 30 min")
        XCTAssertEqual(CompletedTrendBuilder.formatSleep(8), "8 hr")
    }

    @MainActor
    func test_showTrendHandsTheAppAChartAndLeavesTodayOut() {
        let live = CoachLiveContext()
        live.records = [
            record("2026-10-03", sleep: 9),
            record("2026-10-02", sleep: 8),
            record("2026-10-01", sleep: 7),
        ]
        let text = live.showTrend(metric: "sleep", now: now())
        XCTAssertTrue(text.hasPrefix("Chart shown"))
        XCTAssertEqual(live.pendingTrend?.metric, .sleep)
        XCTAssertEqual(live.pendingTrend?.endDateKey, "2026-10-02")
        XCTAssertFalse(text.contains("2026-10-03"))
    }

    func test_filledRecordsOmitTodayAndIncludeGaps() {
        let records = [
            record("2026-10-03", sleep: 9),
            record("2026-10-02", sleep: 8),
            record("2026-09-26", sleep: 7),
        ]
        let filled = CompletedTrendBuilder.filledRecords(
            days: 7,
            records: records,
            settings: settings,
            now: now(),
            calendar: calendar
        )
        XCTAssertEqual(filled.map(\.date).last, "2026-10-02")
        XCTAssertFalse(filled.contains { $0.date == "2026-10-03" })
        XCTAssertEqual(filled.first { $0.date == "2026-09-27" }?.sleepHours, 0)
        XCTAssertEqual(filled.count, 7)
    }

    func test_foodGroupChartUsesTheScoreAndStaysPutIfTheModeChanges() throws {
        let groups = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty, nutritionMode: .foodGroups)
        var day = record("2026-10-02", fiber: 40)
        day.foodGroups = FoodGroupServings(vegetables: 3, isLogged: true)
        let trend = try XCTUnwrap(CompletedTrendBuilder.build(
            metric: .fiber,
            records: [day],
            settings: groups,
            now: now(),
            calendar: calendar
        ))
        XCTAssertEqual(trend.title, "Food groups")
        XCTAssertEqual(trend.goal, 4)
        XCTAssertEqual(trend.bars.first?.value ?? -1, 2, accuracy: 1e-9)
        XCTAssertFalse(trend.headline.contains("g"))

        var grams = groups
        grams.nutritionMode = .fiber
        let again = try XCTUnwrap(CompletedTrendBuilder.build(
            reference: trend.reference(settings: groups),
            records: [day],
            settings: grams,
            calendar: calendar
        ))
        XCTAssertEqual(again.title, "Food groups")
        XCTAssertEqual(again.bars.first?.value ?? -1, 2, accuracy: 1e-9)
    }

    @MainActor
    func test_showTrendUsesTheSelectedNutritionAndMovement() {
        let live = CoachLiveContext()
        var day = record("2026-10-02", fiber: 40, minutes: 30, steps: 4_000)
        day.movementGoal = .exerciseMinutes
        day.foodGroups = FoodGroupServings(vegetables: 3, isLogged: true)
        live.records = [day]
        live.scoringSettings = UserSettings(
            sleepGoal: .sevenHalf,
            fiberGoal: .forty,
            movementGoal: .steps10000,
            nutritionMode: .foodGroups
        )
        let nutrition = live.showTrend(metric: "fiber", now: now())
        XCTAssertTrue(nutrition.contains("Food groups"))
        XCTAssertTrue(nutrition.contains("not fiber grams"))
        XCTAssertEqual(live.pendingTrend?.nutritionModeRaw, NutritionMode.foodGroups.rawValue)

        let movement = live.showTrend(metric: "movement", now: now())
        XCTAssertTrue(movement.contains("Steps"))
        XCTAssertTrue(movement.contains("not exercise minutes"))
        XCTAssertEqual(live.pendingTrend?.movementGoalRaw, MovementGoal.steps10000.rawValue)
        XCTAssertFalse(movement.contains("30 min"))
    }
}
