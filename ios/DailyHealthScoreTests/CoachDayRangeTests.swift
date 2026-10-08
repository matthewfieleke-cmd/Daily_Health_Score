import XCTest
@testable import DailyHealthScore

/// The model names a window; Swift resolves it and renders finished numbers.
final class CoachDayRangeTests: XCTestCase {
    private let today = "2026-09-22"

    private let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)

    private func record(
        _ date: String,
        sleep: Double = 7.0,
        fiber: Double = 30,
        exercise: Double = 30,
        steps: Double = 0,
        movement: MovementGoal = .exerciseMinutes,
        hrv: Double? = nil
    ) -> DailyRecord {
        let goal = UserSettings(sleepGoal: settings.sleepGoal, fiberGoal: settings.fiberGoal, movementGoal: movement)
        let metrics = DailyMetrics(sleepHours: sleep, fiberGrams: fiber, exerciseMinutes: exercise, stepCount: steps)
        let computed = ScoreCalculator.calculate(metrics: metrics, settings: goal)
        return DailyRecord(
            date: date,
            sleepHours: sleep,
            fiberGrams: fiber,
            exerciseMinutes: exercise,
            stepCount: steps,
            sleepHrvSDNNMs: hrv,
            sleepGoal: settings.sleepGoal,
            fiberGoal: settings.fiberGoal,
            movementGoal: movement,
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

    func test_datesWinAndTheWindowIsOrdered() {
        let window = CoachDayRange.resolve(startDate: "2026-09-07", endDate: "2026-09-01", todayKey: today)
        XCTAssertEqual(window, CoachDayRange.Window(startKey: "2026-09-01", endKey: "2026-09-07"))
    }

    func test_offsetsCountBackFromToday() {
        let window = CoachDayRange.resolve(startDaysAgo: 7, endDaysAgo: 1, todayKey: today)
        XCTAssertEqual(window, CoachDayRange.Window(startKey: "2026-09-15", endKey: "2026-09-21"))
    }

    func test_oneEndpointMeansOneDay() {
        XCTAssertEqual(
            CoachDayRange.resolve(startDate: "2026-09-04", todayKey: today),
            CoachDayRange.Window(startKey: "2026-09-04", endKey: "2026-09-04")
        )
        XCTAssertEqual(
            CoachDayRange.resolve(endDaysAgo: 1, todayKey: today),
            CoachDayRange.Window(startKey: "2026-09-21", endKey: "2026-09-21")
        )
    }

    /// The window is clamped rather than refused: asking for a year gets what
    /// the app actually kept, and tomorrow is never a data question.
    func test_windowIsClampedToStoredDaysAndToToday() {
        let long = CoachDayRange.resolve(startDaysAgo: 400, endDaysAgo: 0, todayKey: today)
        XCTAssertEqual(long?.endKey, today)
        XCTAssertEqual(long?.startKey, DateHelpers.addDays(to: today, days: -(DateHelpers.retentionDays - 1)))

        XCTAssertEqual(
            CoachDayRange.resolve(startDate: "2026-09-20", endDate: "2026-12-25", todayKey: today)?.endKey,
            today
        )
        XCTAssertNil(CoachDayRange.resolve(startDate: "2026-12-01", endDate: "2026-12-25", todayKey: today))
        XCTAssertNil(CoachDayRange.resolve(startDate: "2020-01-01", endDate: "2020-02-01", todayKey: today))
        XCTAssertNil(CoachDayRange.resolve(todayKey: today))
        XCTAssertNil(CoachDayRange.resolve(startDate: "not a date", todayKey: today))
    }

    func test_singleDayReadsAsOneSentenceWithGoals() {
        let window = CoachDayRange.Window(startKey: "2026-09-04", endKey: "2026-09-04")
        let text = CoachDayRange.payload(
            records: [record("2026-09-04", sleep: 6.2, fiber: 18, exercise: 12, hrv: 47)],
            window: window,
            todayKey: today
        )
        XCTAssertTrue(text.contains("Fri Sep 4"))
        XCTAssertTrue(text.contains("sleep 6.2 h of 7.5"))
        XCTAssertTrue(text.contains("fiber 18.0 g of 40"))
        XCTAssertTrue(text.contains("exercise minutes 12 of 30"))
        XCTAssertTrue(text.contains("sleep HRV 47 ms"))
        XCTAssertTrue(text.contains("Today is Tue Sep 22, 2026."))
    }

    func test_missingDayIsUnloggedNotZero() {
        let window = CoachDayRange.Window(startKey: "2026-09-04", endKey: "2026-09-04")
        let text = CoachDayRange.payload(records: [], window: window, todayKey: today)
        XCTAssertTrue(text.contains("no record saved"))
        XCTAssertTrue(text.contains("Unlogged, not zero"))
    }

    func test_shortRangeGivesEveryDayAndTheAverage() {
        let window = CoachDayRange.Window(startKey: "2026-09-01", endKey: "2026-09-07")
        let records = ["2026-09-01", "2026-09-02", "2026-09-04", "2026-09-05", "2026-09-06", "2026-09-07"]
            .map { record($0, sleep: 7.0, fiber: 20, exercise: 20) }
        let text = CoachDayRange.payload(records: records, window: window, todayKey: today)

        XCTAssertTrue(text.contains("Sep 1 to Sep 7, 2026 — 7 days, 6 with data."))
        XCTAssertTrue(text.contains("Average across days with data: score"))
        XCTAssertTrue(text.contains("sleep 7.0 h, fiber 20.0 g, exercise minutes 20."))
        XCTAssertTrue(text.contains("No record for Sep 3. Unlogged, not zero."))
        XCTAssertEqual(text.components(separatedBy: "score 7").count - 1, 7, "six day lines plus the average")
    }

    func test_foodGroupDayNamesTheOpenGroup() {
        var day = record("2026-09-04", fiber: 12)
        day.foodGroups = FoodGroupServings(vegetables: 1, isLogged: true)
        let text = CoachDayRange.payload(
            records: [day],
            window: CoachDayRange.Window(startKey: "2026-09-04", endKey: "2026-09-04"),
            todayKey: today,
            nutritionMode: .foodGroups
        )
        XCTAssertTrue(text.contains("food groups 1.3 of 4 (logged, vegetables 1/3)"))
        XCTAssertTrue(text.contains("Apple Health fiber 12.0 g"))
    }

    func test_unloggedFoodGroupsStayNotLogged() {
        let text = CoachDayRange.payload(
            records: [record("2026-09-04", fiber: 40)],
            window: CoachDayRange.Window(startKey: "2026-09-04", endKey: "2026-09-04"),
            todayKey: today,
            nutritionMode: .foodGroups
        )
        XCTAssertTrue(text.contains("food groups 0.0 of 4 (not logged)"))
        XCTAssertTrue(text.contains("Apple Health fiber 40.0 g"))
        XCTAssertFalse(text.contains("fiber 40.0 g of 40"))
    }

    func test_foodGroupAverageCountsLoggedDays() {
        var loggedDay = record("2026-09-01")
        loggedDay.foodGroups = FoodGroupServings(vegetables: 3, fruit: 2, wholeGrains: 3, legumesNuts: 2, fish: 1, isLogged: true)
        let text = CoachDayRange.payload(
            records: [loggedDay, record("2026-09-02")],
            window: CoachDayRange.Window(startKey: "2026-09-01", endKey: "2026-09-02"),
            todayKey: today,
            nutritionMode: .foodGroups
        )
        XCTAssertTrue(text.contains("1 of 2 days logged"))
        XCTAssertTrue(text.contains("not logged"))
    }

    func test_stepGoalRendersStepsAndIgnoresExerciseMinutes() {
        let window = CoachDayRange.Window(startKey: "2026-09-04", endKey: "2026-09-04")
        let text = CoachDayRange.payload(
            records: [record("2026-09-04", exercise: 30, steps: 2_000, movement: .steps8000)],
            window: window,
            todayKey: today
        )
        XCTAssertTrue(text.contains("steps 2000 of 8000"))
        XCTAssertFalse(text.contains("exercise minutes"))
    }

    /// A quarter of day-lines is a worse answer than the shape of the weeks.
    func test_longRangeBecomesWeekAverages() {
        let start = DateHelpers.addDays(to: today, days: -55)!
        let window = CoachDayRange.Window(startKey: start, endKey: today)
        let keys = (0 ... 55).compactMap { DateHelpers.addDays(to: start, days: $0) }
        let text = CoachDayRange.payload(
            records: keys.map { record($0) },
            window: window,
            todayKey: today
        )

        XCTAssertTrue(text.contains("56 days, 56 with data."))
        XCTAssertFalse(text.contains("sleep 7.0 h of 7.5"), "No day lines in a long window")
        XCTAssertEqual(text.components(separatedBy: "7 of 7 days with data").count - 1, 8)
    }

    /// An unreadable request gets the dates back, so the next call can land.
    func test_guidanceNamesTodayAndTheOldestStoredDay() {
        let text = CoachDayRange.guidance(todayKey: today)
        XCTAssertTrue(text.contains("Today is Tue Sep 22, 2026"))
        XCTAssertTrue(text.contains("yyyy-MM-dd"))
        XCTAssertTrue(text.contains("startDaysAgo"))
        let earliest = DateHelpers.addDays(to: today, days: -(DateHelpers.retentionDays - 1))!
        XCTAssertTrue(text.contains(CoachDayRange.monthDay(earliest)))
    }
}
