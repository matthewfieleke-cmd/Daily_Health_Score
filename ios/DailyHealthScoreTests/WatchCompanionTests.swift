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

    func test_strictlyBelowTheBarFires() {
        let decision = PaceNudgeLogic.decision(
            for: .afternoon,
            fiberGrams: 7.9,
            fiberGoal: 40,
            exerciseMinutes: 5.9,
            exerciseGoal: 30,
            now: date(hour: 14),
            calendar: calendar,
            skipIfAlreadyPassed: false
        )
        XCTAssertEqual(decision?.kind, .combined)
    }

    func test_combinedCopyMentionsWalkAndIPhoneNotSleep() {
        let decision = PaceNudgeLogic.decision(
            for: .evening,
            fiberGrams: 0,
            fiberGoal: 40,
            exerciseMinutes: 8,
            exerciseGoal: 30,
            now: date(hour: 18),
            calendar: calendar,
            skipIfAlreadyPassed: false
        )
        XCTAssertEqual(decision?.kind, .combined)
        let body = decision?.body.lowercased() ?? ""
        XCTAssertTrue(body.contains("walk"))
        XCTAssertTrue(body.contains("iphone"))
        XCTAssertFalse(body.contains("sleep"))
        XCTAssertTrue(body.contains("8"))
    }

    func test_quietHoursAfterEveningBound() {
        XCTAssertTrue(PaceNudgeLogic.isInQuietHours(now: date(hour: 20, minute: 30), calendar: calendar))
        XCTAssertFalse(PaceNudgeLogic.isInQuietHours(now: date(hour: 19, minute: 30), calendar: calendar))
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

    func test_endedGoalDoesNotFillOnWatchSnapshot() {
        var goal = WatchGoalSnapshot(
            id: UUID(),
            specificText: "walk",
            targetCount: 3,
            filledMask: 1,
            statusRaw: "ended"
        )
        XCTAssertFalse(goal.fillNextEmpty())
        XCTAssertEqual(goal.filledMask, 1)
    }

    func test_mergeORsLocalPendingBitsUntilPhoneCatchesUp() {
        let id = UUID()
        let pillar = WatchPillarSnapshot(name: "Sleep", value: 7, goal: 7.5, unit: "hr", points: 3.7, maxPoints: 4)
        let fiber = WatchPillarSnapshot(name: "Fiber", value: 10, goal: 40, unit: "g", points: 1, maxPoints: 4)
        let exercise = WatchPillarSnapshot(name: "Exercise", value: 0, goal: 30, unit: "min", points: 0, maxPoints: 2)
        let current = WatchSnapshot(
            dateKey: "2026-08-15",
            totalScore: 4,
            sleep: pillar,
            fiber: fiber,
            exercise: exercise,
            goals: [
                WatchGoalSnapshot(id: id, specificText: "walk", targetCount: 3, filledMask: 1, statusRaw: "active")
            ],
            updatedAt: Date(),
            paceNudgesEnabled: true
        )
        let incoming = WatchSnapshot(
            dateKey: "2026-08-15",
            totalScore: 4,
            sleep: pillar,
            fiber: fiber,
            exercise: exercise,
            goals: [
                WatchGoalSnapshot(id: id, specificText: "walk", targetCount: 3, filledMask: 2, statusRaw: "active")
            ],
            updatedAt: Date(),
            paceNudgesEnabled: true
        )
        let merged = WatchCheckInMerge.apply(current: current, incoming: incoming, pendingFills: [id: 1])
        XCTAssertEqual(merged.snapshot.goals.first?.filledMask, 3)
        XCTAssertEqual(merged.pendingFills[id], 1)

        let caughtUpIncoming = WatchSnapshot(
            dateKey: "2026-08-15",
            totalScore: 4,
            sleep: pillar,
            fiber: fiber,
            exercise: exercise,
            goals: [
                WatchGoalSnapshot(id: id, specificText: "walk", targetCount: 3, filledMask: 3, statusRaw: "active")
            ],
            updatedAt: Date(),
            paceNudgesEnabled: true
        )
        let caughtUp = WatchCheckInMerge.apply(
            current: merged.snapshot,
            incoming: caughtUpIncoming,
            pendingFills: merged.pendingFills
        )
        XCTAssertEqual(caughtUp.snapshot.goals.first?.filledMask, 3)
        XCTAssertNil(caughtUp.pendingFills[id])
    }

    func test_mergeWithoutPendingTakesIncomingIncludingUncheck() {
        let id = UUID()
        let pillar = WatchPillarSnapshot(name: "Sleep", value: 7, goal: 7.5, unit: "hr", points: 3.7, maxPoints: 4)
        let fiber = WatchPillarSnapshot(name: "Fiber", value: 10, goal: 40, unit: "g", points: 1, maxPoints: 4)
        let exercise = WatchPillarSnapshot(name: "Exercise", value: 0, goal: 30, unit: "min", points: 0, maxPoints: 2)
        let current = WatchSnapshot(
            dateKey: "2026-08-15",
            totalScore: 4,
            sleep: pillar,
            fiber: fiber,
            exercise: exercise,
            goals: [
                WatchGoalSnapshot(id: id, specificText: "walk", targetCount: 3, filledMask: 1, statusRaw: "active")
            ],
            updatedAt: Date(),
            paceNudgesEnabled: true
        )
        let incoming = WatchSnapshot(
            dateKey: "2026-08-15",
            totalScore: 4,
            sleep: pillar,
            fiber: fiber,
            exercise: exercise,
            goals: [
                WatchGoalSnapshot(id: id, specificText: "walk", targetCount: 3, filledMask: 0, statusRaw: "active")
            ],
            updatedAt: Date(),
            paceNudgesEnabled: true
        )
        let merged = WatchCheckInMerge.apply(current: current, incoming: incoming, pendingFills: [:])
        XCTAssertEqual(merged.snapshot.goals.first?.filledMask, 0)
    }

    func test_staleDateKeyIsNotToday() {
        let snapshot = WatchSnapshot(
            dateKey: "2020-01-01",
            totalScore: 9,
            sleep: WatchPillarSnapshot(name: "Sleep", value: 8, goal: 7.5, unit: "hr", points: 4, maxPoints: 4),
            fiber: WatchPillarSnapshot(name: "Fiber", value: 40, goal: 40, unit: "g", points: 4, maxPoints: 4),
            exercise: WatchPillarSnapshot(name: "Exercise", value: 30, goal: 30, unit: "min", points: 2, maxPoints: 2),
            goals: [],
            updatedAt: Date(),
            paceNudgesEnabled: true
        )
        XCTAssertFalse(snapshot.isForDay(Date(), calendar: Calendar(identifier: .gregorian)))
    }

    func test_watchBridgeDateKeyMatchesDateHelpers() {
        let date = Date(timeIntervalSince1970: 1_787_000_000)
        XCTAssertEqual(WatchBridge.localDateKey(from: date), DateHelpers.localDateKey(from: date))
    }

    func test_pendingCheckInsRoundTrip() throws {
        let event = WatchCheckInEvent(goalId: UUID(), createdAt: Date(timeIntervalSince1970: 1_787_000_000))
        let json = try XCTUnwrap(WatchBridge.encode([event]))
        let decoded = try XCTUnwrap(WatchBridge.decode([WatchCheckInEvent].self, from: json))
        XCTAssertEqual(decoded, [event])
    }

    func test_snapshotStoreFileRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let snapshot = WatchSnapshot(
            dateKey: "2026-08-16",
            totalScore: 2.9,
            sleep: WatchPillarSnapshot(name: "Sleep", value: 5.4, goal: 7.5, unit: "hr", points: 2.9, maxPoints: 4),
            fiber: WatchPillarSnapshot(name: "Fiber", value: 0, goal: 40, unit: "g", points: 0, maxPoints: 4),
            exercise: WatchPillarSnapshot(name: "Exercise", value: 0, goal: 30, unit: "min", points: 0, maxPoints: 2),
            goals: [],
            updatedAt: Date(timeIntervalSince1970: 1_787_000_000),
            paceNudgesEnabled: true
        )
        XCTAssertTrue(WatchSnapshotStore.save(snapshot, defaults: nil, containerURL: dir))
        let loaded = try XCTUnwrap(WatchSnapshotStore.load(defaults: nil, containerURL: dir))
        XCTAssertEqual(loaded.formattedScore, "2.9")
        XCTAssertEqual(loaded.sleep.value, 5.4, accuracy: 0.01)
    }

    func test_pendingStorePersistsAndClears() {
        let suiteName = "dhs.pendingCheckIn.tests"
        UserDefaults().removePersistentDomain(forName: suiteName)
        let defaults = UserDefaults(suiteName: suiteName)
        let event = WatchCheckInEvent(goalId: UUID(), createdAt: Date(timeIntervalSince1970: 1_787_000_000))
        WatchPendingCheckInStore.save([event], defaults: defaults)
        XCTAssertEqual(WatchPendingCheckInStore.load(defaults: defaults), [event])
        WatchPendingCheckInStore.save([], defaults: defaults)
        XCTAssertTrue(WatchPendingCheckInStore.load(defaults: defaults).isEmpty)
        UserDefaults().removePersistentDomain(forName: suiteName)
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

final class WatchSnapshotBuilderTests: XCTestCase {
    func test_nilTodayStillUsesLocalDateKeyAndZeroScore() {
        let snapshot = WatchSnapshotBuilder.build(today: nil, goals: [], paceNudgesEnabled: true)
        XCTAssertEqual(snapshot.dateKey, DateHelpers.localDateKey())
        XCTAssertEqual(snapshot.totalScore, 0)
        XCTAssertEqual(snapshot.fiber.goal, 40)
        XCTAssertEqual(snapshot.exercise.goal, 30)
        XCTAssertTrue(snapshot.paceNudgesEnabled)
    }

    func test_compactGoalsDropsEndedAndCompleteWhenOverCap() {
        let ended = sampleGoal(text: "ended", status: .ended, filledMask: 1)
        let complete = sampleGoal(text: "done", status: .active, targetCount: 1, filledMask: 1)
        var extras: [SMARTGoal] = []
        for index in 0 ..< 10 {
            extras.append(sampleGoal(text: "g\(index)", status: .active, filledMask: 0))
        }
        let snapshot = WatchSnapshotBuilder.build(
            today: sampleRecord(),
            goals: [ended, complete] + extras,
            paceNudgesEnabled: false
        )
        XCTAssertFalse(snapshot.goals.contains(where: { $0.specificText == "ended" }))
        XCTAssertFalse(snapshot.goals.contains(where: { $0.specificText == "done" }))
        XCTAssertEqual(snapshot.goals.count, 8)
        XCTAssertTrue(snapshot.goals.allSatisfy { !$0.isComplete })
        XCTAssertFalse(snapshot.paceNudgesEnabled)
        XCTAssertEqual(snapshot.totalScore, 6.5, accuracy: 0.01)
    }

    func test_completeActiveGoalIsIncludedWhenUnderCap() {
        let complete = sampleGoal(text: "done", status: .active, targetCount: 1, filledMask: 1)
        let snapshot = WatchSnapshotBuilder.build(
            today: sampleRecord(),
            goals: [complete],
            paceNudgesEnabled: true
        )
        XCTAssertEqual(snapshot.goals.count, 1)
        XCTAssertTrue(snapshot.goals[0].isComplete)
        XCTAssertEqual(snapshot.sleep.value, 7.5)
        XCTAssertEqual(snapshot.fiber.value, 20)
        XCTAssertEqual(snapshot.exercise.value, 8)
    }

    private func sampleRecord() -> DailyRecord {
        DailyRecord(
            date: "2026-08-15",
            sleepHours: 7.5,
            fiberGrams: 20,
            exerciseMinutes: 8,
            sleepGoal: .sevenHalf,
            fiberGoal: .forty,
            sleepScore: 4,
            fiberScore: 2,
            exerciseScore: 0.5,
            totalScore: 6.5,
            sleepPercent: 1,
            fiberPercent: 0.5,
            exercisePercent: 8.0 / 30.0,
            primaryFocus: .fiber,
            suggestion: "",
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    private func sampleGoal(
        text: String,
        status: SMARTGoalStatus,
        targetCount: Int = 3,
        filledMask: Int
    ) -> SMARTGoal {
        SMARTGoal(
            id: UUID(),
            specificText: text,
            targetCount: targetCount,
            relevantTheme: .health,
            timeWindowDays: 7,
            endDate: Date().addingTimeInterval(86_400),
            createdAt: Date(),
            generatedSummary: "",
            filledMask: filledMask,
            status: status,
            remindersEnabled: false,
            reminderHour: 9,
            reminderMinute: 0,
            reminderWeekdaysMask: 127
        )
    }
}
