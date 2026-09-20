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
        XCTAssertNil(CoachPromptSuggestions.metricQuestion(record: record(sleep: 8, fiber: 45, exercise: 45), evening: false))
        XCTAssertFalse(suggestions.contains { $0.contains("grams") || $0.contains("minutes") }, "A good day gets no numbers question")
    }

    /// The chips set the tone: at most one question about the numbers, and the
    /// rest about the person's day, people, learning, or words.
    func test_chipsAreVariedAndCarryAtMostOneMetricQuestion() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        var metricCounts: [Int] = []
        var allChips = Set<String>()
        for day in 1...12 {
            let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 9))!
            let chips = CoachPromptSuggestions.build(
                record: record(sleep: 5, fiber: 10, exercise: 0),
                goals: [goal(filled: 1, target: 5)],
                phase: .day,
                now: now,
                calendar: calendar
            )
            let metric = chips.filter { $0.contains("grams") || $0.contains("minutes") || $0.contains("short sleep") }.count
            metricCounts.append(metric)
            allChips.formUnion(chips)
            XCTAssertLessThanOrEqual(chips.count, CoachPromptSuggestions.maximum)
            XCTAssertTrue(chips.contains("How am I doing on my SMART goals?"))
        }
        XCTAssertTrue(metricCounts.allSatisfy { $0 <= 1 })
        XCTAssertGreaterThanOrEqual(allChips.count, 8, "Twelve days should not show the same four chips")
        XCTAssertTrue(allChips.contains("Help me word a message I've been putting off"))
        XCTAssertTrue(allChips.contains { CoachPromptSuggestions.learning.contains($0) })
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
