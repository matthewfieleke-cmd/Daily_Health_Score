import XCTest
@testable import DailyHealthScore

final class FoodGroupScoreTests: XCTestCase {
    private func logged(
        vegetables: Int = 0,
        fruit: Int = 0,
        wholeGrains: Int = 0,
        legumesNuts: Int = 0,
        fish: Int = 0,
        limited: Int = 0
    ) -> FoodGroupServings {
        FoodGroupServings(
            vegetables: vegetables,
            fruit: fruit,
            wholeGrains: wholeGrains,
            legumesNuts: legumesNuts,
            fish: fish,
            limited: limited,
            isLogged: true
        )
    }

    func test_oneVegetableIsAnExactThird() {
        let points = FoodGroupScore.points(logged(vegetables: 1))
        XCTAssertEqual(points, 1.0 / 3.0 + 1.0, accuracy: 1e-12)
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(points), "1.3")
        XCTAssertEqual(FoodGroupScore.tileLabel(count: 1, group: .vegetables), "1/3")
    }

    func test_twoVegetablesDisplayAsOnePointSevenWithTheLimitPoint() {
        let points = FoodGroupScore.points(logged(vegetables: 2))
        XCTAssertEqual(points, 2.0 / 3.0 + 1.0, accuracy: 1e-12)
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(points), "1.7")
        XCTAssertEqual(FoodGroupScore.tileLabel(count: 2, group: .vegetables), "2/3")
    }

    func test_fullEatMorePlusOneLimitDisplaysThreePointSeven() {
        let points = FoodGroupScore.points(
            logged(vegetables: 3, fruit: 2, wholeGrains: 3, legumesNuts: 2, fish: 1, limited: 1)
        )
        XCTAssertEqual(points, 3.0 + (2.0 / 3.0), accuracy: 1e-12)
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(points), "3.7")
    }

    func test_threeLimitServingsClearThePoint() {
        let points = FoodGroupScore.points(logged(limited: 3))
        XCTAssertEqual(points, 0, accuracy: 1e-12)
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(points), "0.0")
        XCTAssertEqual(FoodGroupScore.tileLabel(count: 3, group: .limited), "0")
    }

    func test_unloggedDayIsZeroAndSavedZerosKeepTheLimitPoint() {
        XCTAssertEqual(FoodGroupScore.points(.empty), 0, accuracy: 1e-12)
        let savedZeros = FoodGroupScore.points(logged())
        XCTAssertEqual(savedZeros, 1, accuracy: 1e-12)
        XCTAssertEqual(ScoreCalculator.formatDisplayScore(savedZeros), "1.0")
    }

    func test_servingsPastFullDoNotAddPointsAndCountsCapAtTwenty() {
        let over = FoodGroupScore.points(logged(vegetables: 9, fruit: 6))
        let full = FoodGroupScore.points(logged(vegetables: 3, fruit: 2))
        XCTAssertEqual(over, full, accuracy: 1e-12)
        XCTAssertEqual(FoodGroupScore.tileLabel(count: 9, group: .vegetables), "Full")

        var servings = FoodGroupServings()
        servings[.vegetables] = 40
        XCTAssertEqual(servings.vegetables, FoodGroupServings.maxCount)
    }

    func test_foodGroupModeIgnoresFiberGrams() {
        let settings = UserSettings(
            sleepGoal: .sevenHalf,
            fiberGoal: .forty,
            nutritionMode: .foodGroups
        )
        let unlogged = ScoreCalculator.calculate(
            metrics: DailyMetrics(sleepHours: 8, fiberGrams: 40, exerciseMinutes: 30),
            settings: settings
        )
        XCTAssertEqual(unlogged.fiberScore, 0, accuracy: 1e-12)

        var metrics = DailyMetrics(sleepHours: 8, fiberGrams: 0, exerciseMinutes: 30)
        metrics.foodGroups = logged()
        let saved = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        XCTAssertEqual(saved.fiberScore, 1, accuracy: 1e-12)
        XCTAssertEqual(saved.totalScore, 4 + 1 + 2, accuracy: 1e-12)
    }

    func test_glanceNamesTheOpenGroupAndAMissingLog() {
        let unlogged = FoodGroupScore.glance(.empty)
        XCTAssertEqual(unlogged.headline, "Log")
        XCTAssertEqual(unlogged.detail, "Not logged")
        XCTAssertEqual(unlogged.historyLine, "not logged")
        XCTAssertEqual(unlogged.spoken, "Not logged")
        XCTAssertEqual(unlogged.coachClause, "not logged")

        let one = FoodGroupScore.glance(logged(vegetables: 1))
        XCTAssertEqual(one.headline, "1.3")
        XCTAssertEqual(one.detail, "Veg 1/3")
        XCTAssertEqual(one.prose, "Vegetables 1/3")
        XCTAssertEqual(one.historyLine, "1.3, Veg 1/3")
        XCTAssertEqual(one.spoken, "1.3 of 4, Vegetables 1/3")
        XCTAssertEqual(one.coachClause, "logged, vegetables 1/3")

        let savedZeros = FoodGroupScore.glance(logged())
        XCTAssertEqual(savedZeros.headline, "1.0")
        XCTAssertEqual(savedZeros.detail, "Veg 0")
        XCTAssertTrue(savedZeros.isLogged)

        let fruitNext = FoodGroupScore.glance(logged(vegetables: 3))
        XCTAssertEqual(fruitNext.headline, "2.0")
        XCTAssertEqual(fruitNext.detail, "Fruit 0")

        let grains = FoodGroupScore.glance(logged(vegetables: 3, fruit: 2, wholeGrains: 1))
        XCTAssertEqual(grains.detail, "Grains 1/3")
        XCTAssertEqual(grains.prose, "Whole grains 1/3")

        let legumes = FoodGroupScore.glance(logged(vegetables: 3, fruit: 2, wholeGrains: 3, legumesNuts: 1))
        XCTAssertEqual(legumes.detail, "Legumes 1 of 2")
        XCTAssertEqual(legumes.prose, "Legumes and nuts 1 of 2")

        let protein = FoodGroupScore.glance(logged(vegetables: 3, fruit: 2, wholeGrains: 3, legumesNuts: 2))
        XCTAssertEqual(protein.detail, "Protein 0")
        XCTAssertEqual(protein.prose, "Healthy protein 0")

        let full = FoodGroupScore.glance(
            logged(vegetables: 3, fruit: 2, wholeGrains: 3, legumesNuts: 2, fish: 1)
        )
        XCTAssertEqual(full.headline, "4.0")
        XCTAssertEqual(full.detail, "All full")
        XCTAssertEqual(full.coachClause, "logged, all full")

        let oneLimited = FoodGroupScore.glance(
            logged(vegetables: 3, fruit: 2, wholeGrains: 3, legumesNuts: 2, fish: 1, limited: 1)
        )
        XCTAssertEqual(oneLimited.headline, "3.7")
        XCTAssertEqual(oneLimited.detail, "1 limited")
        XCTAssertEqual(oneLimited.prose, "1 food to limit")
        XCTAssertEqual(oneLimited.coachClause, "logged, 1 food to limit")

        let threeLimited = FoodGroupScore.glance(
            logged(vegetables: 3, fruit: 2, wholeGrains: 3, legumesNuts: 2, fish: 1, limited: 3)
        )
        XCTAssertEqual(threeLimited.headline, "3.0")
        XCTAssertEqual(threeLimited.detail, "3 limited")
        XCTAssertEqual(threeLimited.prose, "3 foods to limit")
    }

    func test_rollingTileShowsPointsAndHowManyDaysWereLogged() {
        let tile = FoodGroupScore.rollingTile(averagePoints: 1.5, loggedDays: 2, days: 7)
        XCTAssertEqual(tile.value, "1.5 / 4")
        XCTAssertEqual(tile.detail, "2 of 7 logged")
        XCTAssertEqual(
            FoodGroupScore.loggedDayCount([
                day(foodGroups: logged(vegetables: 1)),
                day(foodGroups: .empty)
            ]),
            1
        )
    }

    private func day(foodGroups: FoodGroupServings) -> DailyRecord {
        DailyRecord(
            date: "2026-10-02",
            sleepHours: 0,
            fiberGrams: 0,
            exerciseMinutes: 0,
            foodGroups: foodGroups,
            sleepGoal: .sevenHalf,
            fiberGoal: .forty,
            sleepScore: 0,
            fiberScore: 0,
            exerciseScore: 0,
            totalScore: 0,
            sleepPercent: 0,
            fiberPercent: 0,
            exercisePercent: 0,
            primaryFocus: .fiber,
            suggestion: "",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    func test_healthMetricsDoNotEraseASavedLog() {
        var existing = DailyRecord(
            date: "2026-10-02",
            sleepHours: 7,
            fiberGrams: 10,
            exerciseMinutes: 20,
            foodGroups: logged(vegetables: 2),
            sleepGoal: .sevenHalf,
            fiberGoal: .forty,
            sleepScore: 0,
            fiberScore: 0,
            exerciseScore: 0,
            totalScore: 0,
            sleepPercent: 0,
            fiberPercent: 0,
            exercisePercent: 0,
            primaryFocus: .fiber,
            suggestion: "",
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        existing.foodGroups = logged(vegetables: 2)
        let health = DailyMetrics(sleepHours: 8, fiberGrams: 22, exerciseMinutes: 30, stepCount: 4_000)
        let kept = health.keepingFoodGroups(from: existing)
        XCTAssertEqual(kept.fiberGrams, 22)
        XCTAssertEqual(kept.foodGroups.vegetables, 2)
        XCTAssertTrue(kept.foodGroups.isLogged)
    }
}
