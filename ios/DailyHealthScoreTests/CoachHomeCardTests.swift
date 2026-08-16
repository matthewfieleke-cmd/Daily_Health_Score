import XCTest
@testable import DailyHealthScore

final class CoachHomeCardTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        calendar = cal
    }

    func test_timeWindows_matchClock() {
        XCTAssertEqual(CoachTimeOfDay.current(from: date(hour: 10, minute: 30), calendar: calendar), .morning)
        XCTAssertEqual(CoachTimeOfDay.current(from: date(hour: 11, minute: 0), calendar: calendar), .midday)
        XCTAssertEqual(CoachTimeOfDay.current(from: date(hour: 15, minute: 0), calendar: calendar), .afternoon)
        XCTAssertEqual(CoachTimeOfDay.current(from: date(hour: 18, minute: 0), calendar: calendar), .evening)
        XCTAssertEqual(CoachTimeOfDay.current(from: date(hour: 19, minute: 29), calendar: calendar), .evening)
        XCTAssertEqual(CoachTimeOfDay.current(from: date(hour: 19, minute: 30), calendar: calendar), .night)
        XCTAssertEqual(CoachTimeOfDay.current(from: date(hour: 22, minute: 0), calendar: calendar), .night)
        XCTAssertEqual(CoachTimeOfDay.current(from: date(hour: 3, minute: 0), calendar: calendar), .night)
    }

    func test_eveningPromptRules_forbidAfterLunch() {
        let rules = CoachTimeOfDay.evening.promptRules.lowercased()
        XCTAssertTrue(rules.contains("after lunch"))
        XCTAssertTrue(rules.contains("do not"))
        XCTAssertTrue(rules.contains("dinner") || rules.contains("tonight"))
    }

    func test_fiberAt6pm_doesNotSuggestLunch() {
        let record = makeRecord(sleep: 7.2, fiber: 12, exercise: 40, focus: .fiber)
        let move = HomeCoachCardCopy.nextMove(for: record, timeOfDay: .evening).lowercased()
        XCTAssertFalse(move.contains("after lunch"))
        XCTAssertFalse(move.contains("at lunch"))
        XCTAssertTrue(move.contains("dinner"))
    }

    func test_exerciseInMorning_canUseBeforeLunch() {
        let record = makeRecord(sleep: 7.2, fiber: 40, exercise: 2, focus: .exercise)
        let move = HomeCoachCardCopy.nextMove(for: record, timeOfDay: .morning).lowercased()
        XCTAssertTrue(move.contains("before lunch"))
    }

    func test_fallbackCard_isTwoCompleteBeatsWithStatuses() {
        let record = makeRecord(sleep: 5.0, fiber: 12, exercise: 2, focus: .fiber)
        let card = HomeCoachCardCopy.fallbackCard(
            for: record,
            now: date(hour: 18, minute: 0),
            calendar: calendar
        )
        XCTAssertTrue(card.whereYouAre.contains("of 10"))
        XCTAssertTrue(card.whereYouAre.contains("Sleep"))
        XCTAssertTrue(card.whereYouAre.contains("Fiber"))
        XCTAssertTrue(card.whereYouAre.contains("Exercise"))
        XCTAssertTrue(card.whereYouAre.contains("BELOW GOAL") || card.whereYouAre.contains("NO DATA"))
        XCTAssertLessThan(card.whereYouAre.count, 320)
        XCTAssertFalse(card.whereYouAre.contains("…"))
        XCTAssertFalse(card.nextMove.contains("…"))
        XCTAssertFalse(card.nextMove.isEmpty)
        XCTAssertFalse(card.nextMove.lowercased().contains("after lunch"))
    }

    func test_endingOnSentence_neverAppendsEllipsis() {
        let text = "First sentence is complete. Second sentence is quite a bit longer than the budget allows for."
        let clamped = text.endingOnSentence(maxCharacters: 40)
        XCTAssertEqual(clamped, "First sentence is complete.")
        XCTAssertFalse(clamped.contains("…"))
        XCTAssertFalse(clamped.hasSuffix("..."))

        let runOn = "A long clause without a terminator that exceeds the budget"
        let kept = runOn.endingOnSentence(maxCharacters: 12)
        XCTAssertEqual(kept, runOn)
        XCTAssertFalse(kept.contains("…"))
    }

    func test_cacheKeyIncludesTimeWindow() {
        XCTAssertEqual(CoachTimeOfDay.current(from: date(hour: 10, minute: 16), calendar: calendar).rawValue, "morning")
        XCTAssertEqual(CoachTimeOfDay.current(from: date(hour: 18, minute: 0), calendar: calendar).rawValue, "evening")
    }

    func test_dayPhaseStaysDayAt6pm_whileCoachTimeIsEvening() {
        let sixPM = date(hour: 18, minute: 0)
        XCTAssertEqual(DayPhase.current(from: sixPM, calendar: calendar), .day)
        XCTAssertEqual(CoachTimeOfDay.current(from: sixPM, calendar: calendar), .evening)
        XCTAssertEqual(DayPhase.current(from: date(hour: 19, minute: 30), calendar: calendar), .evening)
        XCTAssertEqual(CoachTimeOfDay.current(from: date(hour: 19, minute: 30), calendar: calendar), .night)
    }

    private func date(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 16
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }

    private func makeRecord(
        sleep: Double,
        fiber: Double,
        exercise: Double,
        focus: PrimaryFocus
    ) -> DailyRecord {
        let metrics = DailyMetrics(
            sleepHours: sleep,
            fiberGrams: fiber,
            exerciseMinutes: exercise
        )
        let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)
        let scores = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        return DailyRecord(
            date: "2026-08-16",
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
            primaryFocus: focus,
            suggestion: "",
            suggestionPhase: .day,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
