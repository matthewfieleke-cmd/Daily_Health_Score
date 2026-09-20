import XCTest
@testable import DailyHealthScore

final class CoachCheckInLogicTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        calendar = cal
    }

    func test_morningUntilFiveThenEveningThroughTheNight() {
        XCTAssertEqual(CoachCheckInLogic.kind(for: date(hour: 5), calendar: calendar), .morning)
        XCTAssertEqual(CoachCheckInLogic.kind(for: date(hour: 11), calendar: calendar), .morning)
        XCTAssertEqual(CoachCheckInLogic.kind(for: date(hour: 16, minute: 59), calendar: calendar), .morning)
        XCTAssertEqual(CoachCheckInLogic.kind(for: date(hour: 17), calendar: calendar), .evening)
        XCTAssertEqual(CoachCheckInLogic.kind(for: date(hour: 22), calendar: calendar), .evening)
        XCTAssertEqual(CoachCheckInLogic.kind(for: date(hour: 2), calendar: calendar), .evening)
    }

    func test_mondayDetection() {
        // September 14, 2026 is a Monday; the 19th is a Saturday.
        XCTAssertTrue(CoachCheckInLogic.isMonday(date(day: 14, hour: 8), calendar: calendar))
        XCTAssertFalse(CoachCheckInLogic.isMonday(date(day: 19, hour: 8), calendar: calendar))
    }

    func test_cacheKeyIgnoresProgressButTracksWhichGoalsExist() {
        let first = CoachTestFixtures.goal(text: "walk after lunch")
        let second = CoachTestFixtures.goal(text: "call a friend")
        let key = CoachCheckInLogic.cacheKey(dateKey: "2026-09-19", kind: .evening, goals: [first, second])
        XCTAssertEqual(key, CoachCheckInLogic.cacheKey(dateKey: "2026-09-19", kind: .evening, goals: [second, first]))

        var logged = first
        logged.fillNextEmpty()
        XCTAssertEqual(key, CoachCheckInLogic.cacheKey(dateKey: "2026-09-19", kind: .evening, goals: [logged, second]))

        XCTAssertNotEqual(key, CoachCheckInLogic.cacheKey(dateKey: "2026-09-19", kind: .evening, goals: [first]))
        XCTAssertNotEqual(key, CoachCheckInLogic.cacheKey(dateKey: "2026-09-19", kind: .morning, goals: [first, second]))
        XCTAssertNotEqual(key, CoachCheckInLogic.cacheKey(dateKey: "2026-09-20", kind: .evening, goals: [first, second]))
    }

    /// A Health sync that lands the first numbers or crosses a goal changes the
    /// signature and earns a rewrite; a few more fiber grams below goal do not.
    func test_statusSignatureChangesOnlyWhenTheShapeOfTheDayDoes() {
        let empty = makeRecord(date: "2026-09-19", sleep: 0, fiber: 0, exercise: 0)
        let morning = makeRecord(date: "2026-09-19", sleep: 4.2, fiber: 7, exercise: 9)
        let moreFiber = makeRecord(date: "2026-09-19", sleep: 4.2, fiber: 19, exercise: 9)
        let fiberMet = makeRecord(date: "2026-09-19", sleep: 4.2, fiber: 41, exercise: 9)
        XCTAssertNotEqual(CoachCheckInLogic.statusSignature(for: empty), CoachCheckInLogic.statusSignature(for: morning))
        XCTAssertEqual(CoachCheckInLogic.statusSignature(for: morning), CoachCheckInLogic.statusSignature(for: moreFiber))
        XCTAssertNotEqual(CoachCheckInLogic.statusSignature(for: moreFiber), CoachCheckInLogic.statusSignature(for: fiberMet))
        XCTAssertTrue(CoachCheckInLogic.statusSignature(for: empty).contains("sleep=none"))
        XCTAssertTrue(CoachCheckInLogic.statusSignature(for: fiberMet).contains("fiber=met"))
        XCTAssertFalse(CoachCheckInLogic.statusSignature(for: morning).contains("focus"), "The weakest pillar flips all day; it must not drive rewrites")

        let goals = [CoachTestFixtures.goal(text: "walk after lunch")]
        let before = CoachCheckInLogic.cacheKey(dateKey: "2026-09-19", kind: .morning, goals: goals, signature: CoachCheckInLogic.statusSignature(for: morning))
        let same = CoachCheckInLogic.cacheKey(dateKey: "2026-09-19", kind: .morning, goals: goals, signature: CoachCheckInLogic.statusSignature(for: moreFiber))
        let crossed = CoachCheckInLogic.cacheKey(dateKey: "2026-09-19", kind: .morning, goals: goals, signature: CoachCheckInLogic.statusSignature(for: fiberMet))
        XCTAssertEqual(before, same)
        XCTAssertNotEqual(before, crossed)
    }

    func test_goalRowsPutUnloggedFirstAndKnowWhatWasLoggedToday() {
        let walk = CoachTestFixtures.goal(text: "walk after lunch")
        let call = CoachTestFixtures.goal(text: "call a friend")
        let paused = CoachTestFixtures.goal(text: "paused thing", status: .paused)
        let todayKey = "2026-09-19"
        let loggedToday = CoachTestFixtures.checkIn(goalId: walk.id, occurredAt: CoachTestFixtures.now)
        var dated = loggedToday
        dated.localDateKey = todayKey
        let rows = CoachCheckInLogic.goalRows(goals: [walk, call, paused], activities: [dated], todayKey: todayKey)
        XCTAssertEqual(rows.map(\.title), ["call a friend", "walk after lunch"])
        XCTAssertTrue(rows[1].loggedToday)
        XCTAssertFalse(rows[1].canLog)
        XCTAssertTrue(rows[0].canLog)
        XCTAssertTrue(CoachCheckInLogic.goalsBlock(rows).contains("logged today"))
        XCTAssertEqual(CoachCheckInLogic.goalsBlock([]), "No active SMART goals.")
    }

    func test_paceBehindCountAndShrinkDirective() {
        // Created 5 days ago in a 10-day window with 8 check-ins expected: 4 by now.
        var goal = CoachTestFixtures.goal(text: "read ten pages", target: 8)
        goal.timeWindowDays = 10
        goal.createdAt = CoachTestFixtures.now.addingTimeInterval(-5 * 86_400)
        goal.endDate = CoachTestFixtures.now.addingTimeInterval(5 * 86_400)
        goal.filledMask = SMARTGoalProgress.mask(filledCount: 1, targetCount: 8)
        XCTAssertEqual(SMARTGoalPace.behindCount(goal: goal, now: CoachTestFixtures.now, calendar: calendar), 3)
        let directive = SMARTGoalPace.directive(goals: [goal], now: CoachTestFixtures.now, calendar: calendar)
        XCTAssertNotNil(directive)
        XCTAssertTrue(directive?.contains("read ten pages") == true)
        XCTAssertTrue(directive?.contains("not a failure") == true)

        goal.filledMask = SMARTGoalProgress.mask(filledCount: 3, targetCount: 8)
        XCTAssertEqual(SMARTGoalPace.behindCount(goal: goal, now: CoachTestFixtures.now, calendar: calendar), 1)
        XCTAssertNil(SMARTGoalPace.directive(goals: [goal], now: CoachTestFixtures.now, calendar: calendar))

        var complete = goal
        complete.filledMask = SMARTGoalProgress.mask(filledCount: 8, targetCount: 8)
        XCTAssertEqual(SMARTGoalPace.behindCount(goal: complete, now: CoachTestFixtures.now, calendar: calendar), 0)
    }

    func test_trendDigestComparesLastWeekToTheWeekBefore() {
        let now = date(day: 21, hour: 8) // Monday, September 21, 2026
        var records: [DailyRecord] = []
        for offset in 1...14 {
            let day = calendar.date(byAdding: .day, value: -offset, to: now)!
            let key = DateHelpers.localDateKey(from: day)
            let recent = offset <= 7
            records.append(makeRecord(
                date: key,
                sleep: recent ? 7.5 : 6.0,
                fiber: recent ? 42 : 20,
                exercise: recent ? 40 : 10
            ))
        }
        let digest = CoachTrendDigest.build(records: records, goals: [], activities: [], now: now, calendar: calendar)
        XCTAssertNotNil(digest)
        XCTAssertTrue(digest?.facts.first?.contains("up from") == true)
        XCTAssertTrue(digest?.facts.contains { $0.contains("Fiber goal reached on 7 of 7") } == true)
        XCTAssertTrue(digest?.sentence.contains("of 10") == true)
        XCTAssertTrue(digest?.promptBlock.hasPrefix("TREND FACTS") == true)
        XCTAssertFalse(digest?.sentence.contains("**") == true)
    }

    func test_trendDigestNeedsEnoughDays() {
        let now = date(day: 21, hour: 8)
        let records = (1...2).map { offset -> DailyRecord in
            let day = calendar.date(byAdding: .day, value: -offset, to: now)!
            return makeRecord(date: DateHelpers.localDateKey(from: day), sleep: 7, fiber: 30, exercise: 30)
        }
        XCTAssertNil(CoachTrendDigest.build(records: records, goals: [], activities: [], now: now, calendar: calendar))
    }

    func test_acquaintanceIsNeededOnceThenNever() {
        XCTAssertTrue(CoachAcquaintance.isNeeded(threads: [], liveMemoryCount: 0))
        XCTAssertFalse(CoachAcquaintance.isNeeded(threads: [], liveMemoryCount: 5))
        let intake = CoachThread(kind: .acquaintance, title: "Getting acquainted", messageCount: 2)
        XCTAssertFalse(CoachAcquaintance.isNeeded(threads: [intake], liveMemoryCount: 0))
        XCTAssertEqual(CoachAcquaintance.existingThread(in: [intake])?.id, intake.id)
        XCTAssertTrue(CoachAcquaintance.opener.contains("?"))
        XCTAssertTrue(CoachAcquaintance.opener.contains("what should I call you"))
        XCTAssertTrue(CoachAcquaintance.opener.contains("who's at home"))
    }

    func test_goalCheckInRequestValidatesAgainstLiveGoals() {
        let goal = CoachTestFixtures.goal(text: "walk after lunch")
        let request = CoachGoalCheckInRequest.make(
            goalID: goal.id.uuidString, when: "yesterday", note: "did it", goals: [goal],
            now: CoachTestFixtures.now, calendar: calendar
        )
        XCTAssertEqual(request?.goalId, goal.id)
        XCTAssertEqual(request?.goalTitle, "walk after lunch")
        XCTAssertTrue((request?.occurredAt ?? CoachTestFixtures.now) < CoachTestFixtures.now)
        XCTAssertNil(CoachGoalCheckInRequest.make(goalID: UUID().uuidString, when: "today", note: "", goals: [goal]))
        XCTAssertNil(CoachGoalCheckInRequest.make(goalID: "not-a-uuid", when: "today", note: "", goals: [goal]))
        let paused = CoachTestFixtures.goal(status: .paused)
        XCTAssertNil(CoachGoalCheckInRequest.make(goalID: paused.id.uuidString, when: "today", note: "", goals: [paused]))
    }

    // MARK: Helpers

    private func date(day: Int = 19, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute))!
    }

    private func makeRecord(date: String, sleep: Double, fiber: Double, exercise: Double) -> DailyRecord {
        let metrics = DailyMetrics(sleepHours: sleep, fiberGrams: fiber, exerciseMinutes: exercise)
        let settings = UserSettings(sleepGoal: .sevenHalf, fiberGoal: .forty)
        let scores = ScoreCalculator.calculate(metrics: metrics, settings: settings)
        return DailyRecord(
            date: date,
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
            primaryFocus: ScoreCalculator.determinePrimaryFocus(scores),
            suggestion: "",
            suggestionPhase: .day,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}
