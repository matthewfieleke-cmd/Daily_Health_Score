import XCTest
@testable import DailyHealthScore

final class CoachPromptSuggestionsTests: XCTestCase {
    private func record(sleep: Double, fiber: Double, exercise: Double) -> DailyRecord {
        let metrics = DailyMetrics(sleepHours: sleep, fiberGrams: fiber, exerciseMinutes: exercise)
        let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)
        let scores = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        return DailyRecord(
            date: DateHelpers.localDateKey(),
            sleepHours: sleep,
            fiberGrams: fiber,
            exerciseMinutes: exercise,
            sleepHrvSDNNMs: nil,
            sleepGoal: settings.sleepGoal,
            fiberGoal: settings.fiberGoal,
            sleepScore: scores.sleepScore,
            fiberScore: scores.fiberScore,
            exerciseScore: scores.exerciseScore,
            totalScore: scores.totalScore,
            sleepPercent: scores.sleepPercent,
            fiberPercent: scores.fiberPercent,
            exercisePercent: scores.exercisePercent,
            primaryFocus: .fiber,
            suggestion: "",
            suggestionPhase: .day,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }

    private func goal(filled: Int, target: Int) -> SMARTGoal {
        var mask = 0
        for index in 0 ..< filled { mask |= (1 << index) }
        return SMARTGoal(
            id: UUID(),
            specificText: "walk after dinner",
            targetCount: target,
            relevantTheme: .health,
            timeWindowDays: 7,
            endDate: Calendar.current.date(byAdding: .day, value: 4, to: Date())!,
            createdAt: Date(),
            generatedSummary: "",
            filledMask: mask,
            status: .active,
            remindersEnabled: false,
            reminderHour: 9,
            reminderMinute: 0,
            reminderWeekdaysMask: 127
        )
    }

    func test_fiberGapInAStarterIsComputedNotGuessed() {
        let suggestions = CoachPromptSuggestions.build(
            record: record(sleep: 7.5, fiber: 28, exercise: 30),
            phase: .day
        )

        XCTAssertTrue(suggestions.contains("How do I get 12 more grams of fiber today?"))
    }

    func test_unloggedFiberAsksHowRatherThanNamingAGap() {
        let suggestions = CoachPromptSuggestions.build(
            record: record(sleep: 7.5, fiber: 0, exercise: 30),
            phase: .day
        )

        XCTAssertTrue(suggestions.contains("What are easy ways to hit my fiber goal?"))
        XCTAssertFalse(suggestions.contains { $0.contains("more grams") })
    }

    func test_eveningDoesNotSuggestSomethingThatNeededTheWholeDay() {
        let suggestions = CoachPromptSuggestions.build(
            record: record(sleep: 7.5, fiber: 40, exercise: 0),
            phase: .evening
        )

        XCTAssertFalse(suggestions.contains { $0.contains("fit in") })
        XCTAssertTrue(suggestions.contains("Help me set up tomorrow"))
    }

    func test_activeGoalSurfacesAGoalStarter() {
        let suggestions = CoachPromptSuggestions.build(
            record: record(sleep: 7.5, fiber: 40, exercise: 30),
            goals: [goal(filled: 1, target: 5)],
            phase: .day
        )

        XCTAssertTrue(suggestions.contains("How am I doing on my SMART goals?"))
    }

    func test_completedGoalDoesNotSurfaceAGoalStarter() {
        let suggestions = CoachPromptSuggestions.build(
            record: record(sleep: 7.5, fiber: 40, exercise: 30),
            goals: [goal(filled: 5, target: 5)],
            phase: .day
        )

        XCTAssertFalse(suggestions.contains("How am I doing on my SMART goals?"))
    }

    func test_aGoodDayStillOffersSomewhereToGo() {
        let suggestions = CoachPromptSuggestions.build(
            record: record(sleep: 8, fiber: 45, exercise: 45),
            phase: .day
        )

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains("What's worth protecting tomorrow?"))
    }

    func test_brandNewUserWithNoRecordStillGetsStarters() {
        let suggestions = CoachPromptSuggestions.build(record: nil)

        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertLessThanOrEqual(suggestions.count, CoachPromptSuggestions.maximum)
    }

    func test_startersAreCappedAndUnique() {
        let suggestions = CoachPromptSuggestions.build(
            record: record(sleep: 5, fiber: 10, exercise: 0),
            goals: [goal(filled: 1, target: 5)],
            phase: .day
        )

        XCTAssertLessThanOrEqual(suggestions.count, CoachPromptSuggestions.maximum)
        XCTAssertEqual(Set(suggestions).count, suggestions.count)
    }
}
