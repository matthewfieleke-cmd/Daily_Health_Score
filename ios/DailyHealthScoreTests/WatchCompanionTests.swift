import XCTest
@testable import DailyHealthScore

final class PaceNudgeLogicTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: hour, minute: minute))!
    }

    func test_sixAMDoesNotFireAnything() {
        let now = date(hour: 6)
        XCTAssertTrue(PaceNudgeLogic.isInQuietHours(now: now, calendar: calendar))
        XCTAssertFalse(PaceNudgeSlot.afternoon.hasPassed(at: now, calendar: calendar))
    }

    func test_sixAMSchedulesFutureSlotsWhenBehindButDoesNotTreatThemAsPassed() {
        let now = date(hour: 6)
        let upcoming = PaceNudgeLogic.upcomingDecisions(
            fiberGrams: 0,
            fiberGoal: 40,
            exerciseMinutes: 0,
            exerciseGoal: 30,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(upcoming.map(\.slot), [.afternoon, .lateAfternoon, .evening])
        XCTAssertTrue(upcoming.allSatisfy { !$0.slot.hasPassed(at: now, calendar: calendar) })
    }

    func test_sixPMEightExerciseMinutesIsBehindTheEveningBar() {
        let now = date(hour: 18)
        let evening = PaceNudgeLogic.decision(
            for: .evening,
            fiberGrams: 40,
            fiberGoal: 40,
            exerciseMinutes: 8,
            exerciseGoal: 30,
            now: now,
            calendar: calendar,
            skipIfAlreadyPassed: true
        )
        XCTAssertEqual(evening?.kind, .exercise)
        XCTAssertTrue(evening?.body.contains("8") ?? false)
    }

    func test_sixPMDoesNotRefireAfternoonOrLateAfternoon() {
        let now = date(hour: 18)
        let upcoming = PaceNudgeLogic.upcomingDecisions(
            fiberGrams: 0,
            fiberGoal: 40,
            exerciseMinutes: 8,
            exerciseGoal: 30,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(upcoming.map(\.slot), [.evening])
        XCTAssertEqual(upcoming.first?.kind, .combined)
    }

    func test_onPaceFiberAndExerciseProducesNothing() {
        let now = date(hour: 15)
        let decision = PaceNudgeLogic.decision(
            for: .afternoon,
            fiberGrams: 20,
            fiberGoal: 40,
            exerciseMinutes: 20,
            exerciseGoal: 30,
            now: now,
            calendar: calendar,
            skipIfAlreadyPassed: false
        )
        XCTAssertNil(decision)
    }

    func test_fiberOnlyDoesNotMentionExercise() {
        let decision = PaceNudgeLogic.decision(
            for: .lateAfternoon,
            fiberGrams: 10,
            fiberGoal: 40,
            exerciseMinutes: 30,
            exerciseGoal: 30,
            now: date(hour: 16),
            calendar: calendar,
            skipIfAlreadyPassed: false
        )
        XCTAssertEqual(decision?.kind, .fiber)
        XCTAssertFalse(decision?.body.lowercased().contains("walk") ?? true)
        XCTAssertTrue(decision?.body.contains("iPhone") ?? false)
    }

    func test_exerciseOnlyDoesNotMentionFiber() {
        let decision = PaceNudgeLogic.decision(
            for: .lateAfternoon,
            fiberGrams: 40,
            fiberGoal: 40,
            exerciseMinutes: 8,
            exerciseGoal: 30,
            now: date(hour: 16),
            calendar: calendar,
            skipIfAlreadyPassed: false
        )
        XCTAssertEqual(decision?.kind, .exercise)
        XCTAssertFalse(decision?.title.lowercased().contains("fiber") ?? true)
    }

    func test_sleepCannotTriggerANudgeBecauseLogicNeverSeesIt() {
        // Total score 3.2 from sleep-only would look "behind"; fiber and exercise
        // at goal must still produce nothing.
        let decision = PaceNudgeLogic.decision(
            for: .evening,
            fiberGrams: 40,
            fiberGoal: 40,
            exerciseMinutes: 30,
            exerciseGoal: 30,
            now: date(hour: 19),
            calendar: calendar,
            skipIfAlreadyPassed: false
        )
        XCTAssertNil(decision)
    }

    func test_exactlyOnTheBarDoesNotFire() {
        // Afternoon fiber bar is 20% of 40 = 8.
        let decision = PaceNudgeLogic.decision(
            for: .afternoon,
            fiberGrams: 8,
            fiberGoal: 40,
            exerciseMinutes: 6,
            exerciseGoal: 30,
            now: date(hour: 14),
            calendar: calendar,
            skipIfAlreadyPassed: false
        )
        XCTAssertNil(decision)
    }

    func test_installAfterASlotHasPassedDoesNotScheduleThatSlot() {
        let now = date(hour: 16)
        XCTAssertNil(
            PaceNudgeLogic.decision(
                for: .afternoon,
                fiberGrams: 0,
                fiberGoal: 40,
                exerciseMinutes: 0,
                exerciseGoal: 30,
                now: now,
                calendar: calendar,
                skipIfAlreadyPassed: true
            )
        )
    }
}

final class WatchSnapshotTests: XCTestCase {
    func test_roundTripJSON() throws {
        let snapshot = WatchSnapshot(
            dateKey: "2026-08-15",
            totalScore: 7.4,
            sleep: WatchPillarSnapshot(name: "Sleep", value: 7.5, goal: 7.5, unit: "hr", points: 4, maxPoints: 4),
            fiber: WatchPillarSnapshot(name: "Fiber", value: 12, goal: 40, unit: "g", points: 1.2, maxPoints: 4),
            exercise: WatchPillarSnapshot(name: "Exercise", value: 8, goal: 30, unit: "min", points: 0.5, maxPoints: 2),
            goals: [
                WatchGoalSnapshot(
                    id: UUID(),
                    specificText: "walk after dinner",
                    targetCount: 5,
                    filledMask: 1,
                    statusRaw: "active"
                )
            ],
            updatedAt: Date(timeIntervalSince1970: 1_787_000_000),
            paceNudgesEnabled: true
        )
        let json = try XCTUnwrap(WatchBridge.encode(snapshot))
        let decoded = try XCTUnwrap(WatchBridge.decode(WatchSnapshot.self, from: json))
        XCTAssertEqual(decoded.dateKey, snapshot.dateKey)
        XCTAssertEqual(decoded.formattedScore, "7.4")
        XCTAssertEqual(decoded.goals.first?.filledCount, 1)
        XCTAssertEqual(decoded.exercise.formattedValue, "8")
    }

    func test_fillNextEmptyAdvancesTheLowestOpenCircle() {
        var goal = WatchGoalSnapshot(
            id: UUID(),
            specificText: "walk",
            targetCount: 3,
            filledMask: 1,
            statusRaw: "active"
        )
        XCTAssertTrue(goal.fillNextEmpty())
        XCTAssertEqual(goal.filledCount, 2)
        XCTAssertTrue(goal.fillNextEmpty())
        XCTAssertTrue(goal.isComplete)
        XCTAssertFalse(goal.fillNextEmpty())
    }

    func test_scoreFractionClamps() {
        let high = WatchSnapshot(
            dateKey: "2026-08-15",
            totalScore: 11,
            sleep: WatchPillarSnapshot(name: "Sleep", value: 8, goal: 7.5, unit: "hr", points: 4, maxPoints: 4),
            fiber: WatchPillarSnapshot(name: "Fiber", value: 40, goal: 40, unit: "g", points: 4, maxPoints: 4),
            exercise: WatchPillarSnapshot(name: "Exercise", value: 30, goal: 30, unit: "min", points: 2, maxPoints: 2),
            goals: [],
            updatedAt: Date(),
            paceNudgesEnabled: true
        )
        XCTAssertEqual(high.scoreFraction, 1)
    }
}

final class SMARTGoalWatchMergeTests: XCTestCase {
    func test_fillNextEmptyORsBitsAndStopsWhenComplete() {
        var goal = SMARTGoal(
            id: UUID(),
            specificText: "walk",
            targetCount: 3,
            relevantTheme: .health,
            timeWindowDays: 7,
            endDate: Date().addingTimeInterval(86_400),
            createdAt: Date(),
            generatedSummary: "",
            filledMask: 0,
            status: .active,
            remindersEnabled: false,
            reminderHour: 9,
            reminderMinute: 0,
            reminderWeekdaysMask: 127
        )
        XCTAssertTrue(goal.fillNextEmpty())
        XCTAssertTrue(goal.fillNextEmpty())
        XCTAssertTrue(goal.fillNextEmpty())
        XCTAssertTrue(goal.isComplete)
        XCTAssertFalse(goal.fillNextEmpty())
        XCTAssertEqual(goal.filledMask, 7)
    }

    func test_endedGoalDoesNotFill() {
        var goal = SMARTGoal(
            id: UUID(),
            specificText: "walk",
            targetCount: 3,
            relevantTheme: .health,
            timeWindowDays: 7,
            endDate: Date().addingTimeInterval(-86_400),
            createdAt: Date(),
            generatedSummary: "",
            filledMask: 1,
            status: .ended,
            remindersEnabled: false,
            reminderHour: 9,
            reminderMinute: 0,
            reminderWeekdaysMask: 127
        )
        XCTAssertFalse(goal.fillNextEmpty())
        XCTAssertEqual(goal.filledMask, 1)
    }

    func test_smartGoalIsCodable() throws {
        let goal = SMARTGoal(
            id: UUID(),
            specificText: "walk after dinner",
            targetCount: 5,
            relevantTheme: .health,
            timeWindowDays: 7,
            endDate: Date(timeIntervalSince1970: 1_787_000_000),
            createdAt: Date(timeIntervalSince1970: 1_786_400_000),
            generatedSummary: "summary",
            filledMask: 3,
            status: .active,
            remindersEnabled: true,
            reminderHour: 9,
            reminderMinute: 0,
            reminderWeekdaysMask: 127
        )
        let data = try JSONEncoder().encode(goal)
        let decoded = try JSONDecoder().decode(SMARTGoal.self, from: data)
        XCTAssertEqual(decoded, goal)
    }
}
