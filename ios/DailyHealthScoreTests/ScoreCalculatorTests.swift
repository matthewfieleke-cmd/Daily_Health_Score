import XCTest
@testable import DailyHealthScore

final class ScoreCalculatorTests: XCTestCase {
    private let defaultSettings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)

    // MARK: - calculate

    func test_allZeroMetrics_yieldsZeroScores() {
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 0),
            settings: defaultSettings
        )
        XCTAssertEqual(computed.sleepScore, 0)
        XCTAssertEqual(computed.fiberScore, 0)
        XCTAssertEqual(computed.exerciseScore, 0)
        XCTAssertEqual(computed.totalScore, 0)
        XCTAssertEqual(computed.sleepPercent, 0)
        XCTAssertEqual(computed.fiberPercent, 0)
        XCTAssertEqual(computed.exercisePercent, 0)
    }

    func test_exactlyAtGoals_yieldsPerfectScore() {
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 7.5, fiberGrams: 40, exerciseMinutes: 30),
            settings: defaultSettings
        )
        XCTAssertEqual(computed.sleepScore, 4, accuracy: 1e-9)
        XCTAssertEqual(computed.fiberScore, 4, accuracy: 1e-9)
        XCTAssertEqual(computed.exerciseScore, 2, accuracy: 1e-9)
        XCTAssertEqual(computed.totalScore, 10, accuracy: 1e-9)
    }

    func test_metricsAboveGoals_clampToFullPoints() {
        // Score is clamped at the goal but the *percent* is the raw ratio (used by progress bars).
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 9, fiberGrams: 60, exerciseMinutes: 60),
            settings: defaultSettings
        )
        XCTAssertEqual(computed.sleepScore, 4, accuracy: 1e-9)
        XCTAssertEqual(computed.fiberScore, 4, accuracy: 1e-9)
        XCTAssertEqual(computed.exerciseScore, 2, accuracy: 1e-9)
        XCTAssertEqual(computed.totalScore, 10, accuracy: 1e-9)
        XCTAssertEqual(computed.sleepPercent, 9.0 / 7.5, accuracy: 1e-9)
        XCTAssertEqual(computed.fiberPercent, 60.0 / 40, accuracy: 1e-9)
        XCTAssertEqual(computed.exercisePercent, 60.0 / 30, accuracy: 1e-9)
    }

    func test_partialMetrics_scaleLinearly() {
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 3.75, fiberGrams: 20, exerciseMinutes: 15),
            settings: defaultSettings
        )
        XCTAssertEqual(computed.sleepScore, 2, accuracy: 1e-9)
        XCTAssertEqual(computed.fiberScore, 2, accuracy: 1e-9)
        XCTAssertEqual(computed.exerciseScore, 1, accuracy: 1e-9)
        XCTAssertEqual(computed.totalScore, 5, accuracy: 1e-9)
    }

    func test_screenshotDay_yieldsExpectedScore() {
        // From the Apple Health Summary screenshot: 4h 56m sleep, 12.5g fiber, 15 min exercise.
        let sleepHours = 4.0 + 56.0 / 60.0
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: sleepHours, fiberGrams: 12.5, exerciseMinutes: 15),
            settings: defaultSettings
        )
        XCTAssertEqual(computed.sleepScore, (sleepHours / 7.5) * 4, accuracy: 1e-9)
        XCTAssertEqual(computed.fiberScore, (12.5 / 40) * 4, accuracy: 1e-9)
        XCTAssertEqual(computed.exerciseScore, (15.0 / 30) * 2, accuracy: 1e-9)
        XCTAssertEqual(
            computed.totalScore,
            computed.sleepScore + computed.fiberScore + computed.exerciseScore,
            accuracy: 1e-9
        )
    }

    func test_stepGoalScalesToTwoPointsAndIgnoresExerciseMinutes() {
        let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty, movementGoal: .steps8000)
        let half = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 30, stepCount: 4_000),
            settings: settings
        )
        XCTAssertEqual(half.exerciseScore, 1, accuracy: 1e-9)
        XCTAssertEqual(half.exercisePercent, 0.5, accuracy: 1e-9)

        let quarter = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 0, stepCount: 2_000),
            settings: settings
        )
        XCTAssertEqual(quarter.exerciseScore, 0.5, accuracy: 1e-9)
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(quarter.exerciseScore), "0.5")

        let over = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 0, stepCount: 12_000),
            settings: UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty, movementGoal: .steps10000)
        )
        XCTAssertEqual(over.exerciseScore, 2, accuracy: 1e-9)

        let minutesStillScoreMinutes = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 15, stepCount: 8_000),
            settings: defaultSettings
        )
        XCTAssertEqual(minutesStillScoreMinutes.exerciseScore, 1, accuracy: 1e-9)
    }

    func test_stepDisplayRoundsToNearestTenth() {
        let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty, movementGoal: .steps8000)
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 0, fiberGrams: 0, exerciseMinutes: 0, stepCount: 2_500),
            settings: settings
        )
        XCTAssertEqual(computed.exerciseScore, 0.625, accuracy: 1e-9)
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(computed.exerciseScore), "0.6")
    }

    func test_alternativeSleepAndFiberGoals_changeScoring() {
        let settings = UserSettings(sleepGoal: .eight, fiberGoal: .fifty)
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 8, fiberGrams: 50, exerciseMinutes: 30),
            settings: settings
        )
        XCTAssertEqual(computed.totalScore, 10, accuracy: 1e-9)
    }

    // MARK: - determinePrimaryFocus

    func test_primaryFocus_allGoalsMet_returnsMaintain() {
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 8, fiberGrams: 45, exerciseMinutes: 35),
            settings: defaultSettings
        )
        XCTAssertEqual(ScoreCalculator.determinePrimaryFocus(computed), .maintain)
    }

    func test_primaryFocus_sleepIsLowest_returnsSleep() {
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 5, fiberGrams: 38, exerciseMinutes: 25),
            settings: defaultSettings
        )
        XCTAssertEqual(ScoreCalculator.determinePrimaryFocus(computed), .sleep)
    }

    func test_primaryFocus_fiberIsLowest_returnsFiber() {
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 7, fiberGrams: 10, exerciseMinutes: 25),
            settings: defaultSettings
        )
        XCTAssertEqual(ScoreCalculator.determinePrimaryFocus(computed), .fiber)
    }

    func test_primaryFocus_exerciseIsLowest_returnsExercise() {
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 7, fiberGrams: 35, exerciseMinutes: 5),
            settings: defaultSettings
        )
        XCTAssertEqual(ScoreCalculator.determinePrimaryFocus(computed), .exercise)
    }

    func test_primaryFocus_tieBetweenSleepAndFiber_prefersSleep() {
        // sleepPercent = fiberPercent = 0.5; exercise is full → tie at 0.5.
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 7.5 * 0.5, fiberGrams: 40 * 0.5, exerciseMinutes: 30),
            settings: defaultSettings
        )
        XCTAssertEqual(ScoreCalculator.determinePrimaryFocus(computed), .sleep)
    }

    func test_primaryFocus_tieBetweenFiberAndExercise_prefersFiber() {
        let computed = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 7.5, fiberGrams: 40 * 0.5, exerciseMinutes: 15),
            settings: defaultSettings
        )
        XCTAssertEqual(ScoreCalculator.determinePrimaryFocus(computed), .fiber)
    }

    // MARK: - formatDisplayScore

    func test_formatDisplayScore_alwaysOneDecimal() {
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(0), "0.0")
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(7), "7.0")
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(7.04), "7.0")
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(7.16), "7.2")
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(10), "10.0")
    }

    func test_primaryFocusLabel_mapsAllCases() {
        XCTAssertEqual(ScoreCalculator.primaryFocusLabel(.sleep), "Sleep")
        XCTAssertEqual(ScoreCalculator.primaryFocusLabel(.fiber), "Fiber")
        XCTAssertEqual(ScoreCalculator.primaryFocusLabel(.exercise), "Exercise")
        XCTAssertEqual(ScoreCalculator.primaryFocusLabel(.maintain), "Maintain")
    }
}
