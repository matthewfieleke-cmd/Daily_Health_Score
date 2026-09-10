import SwiftData
import XCTest
@testable import DailyHealthScore

/// Synthetic SMART-goal and coach fixtures. These are not real user records.
enum CoachTestFixtures {
    static let now = Date(timeIntervalSince1970: 2_000_000_000)

    static func goal(
        id: UUID = UUID(),
        text: String = "walk for ten minutes after lunch",
        target: Int = 5,
        mask: Int = 0,
        status: SMARTGoalStatus = .active,
        endDate: Date? = nil,
        plan: SMARTGoalPlan = .empty
    ) -> SMARTGoal {
        SMARTGoal(
            id: id,
            specificText: text,
            targetCount: target,
            relevantTheme: .health,
            timeWindowDays: 7,
            endDate: endDate ?? now.addingTimeInterval(7 * 86_400),
            createdAt: now.addingTimeInterval(-2 * 86_400),
            generatedSummary: "fixture",
            filledMask: mask,
            status: status,
            remindersEnabled: false,
            reminderHour: 9,
            reminderMinute: 0,
            reminderWeekdaysMask: 127,
            plan: plan
        )
    }

    static func checkIn(
        goalId: UUID,
        occurredAt: Date?,
        id: UUID = UUID(),
        source: SMARTGoalActivitySource = .iPhone,
        clientEventId: String = "",
        countsTowardTarget: Bool = true
    ) -> SMARTGoalActivity {
        SMARTGoalActivity(
            id: id,
            goalId: goalId,
            kind: countsTowardTarget ? .checkIn : .fallbackCheckIn,
            source: source,
            occurredAt: occurredAt,
            recordedAt: now,
            localDateKey: occurredAt.map { DateHelpers.localDateKey(from: $0) } ?? "",
            clientEventId: clientEventId,
            countsTowardTarget: countsTowardTarget
        )
    }
}

final class SMARTGoalActivityLogicTests: XCTestCase {
    func test_undatedMigratedCheckInsPreserveCountWithoutInventingDates() {
        let goalId = UUID()
        let events = SMARTGoalActivityLogic.undatedCheckInsFromLegacyMask(
            mask: 0b10000001,
            targetCount: 8,
            goalId: goalId,
            recordedAt: CoachTestFixtures.now
        )
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.allSatisfy { $0.occurredAt == nil })
        XCTAssertTrue(events.allSatisfy { $0.source == .migration })
        XCTAssertTrue(SMARTGoalActivityLogic.hasUndatedProgress(events))
        XCTAssertTrue(SMARTGoalActivityLogic.datedOccurrenceKeys(events).isEmpty)
        XCTAssertEqual(SMARTGoalActivityLogic.filledMask(from: events, targetCount: 8), 0b011)
    }

    func test_undoRemovesACheckInWithoutDeletingHistory() {
        let goalId = UUID()
        let checkIn = CoachTestFixtures.checkIn(goalId: goalId, occurredAt: CoachTestFixtures.now)
        let undo = SMARTGoalActivity(
            goalId: goalId,
            kind: .undo,
            source: .userEntry,
            occurredAt: CoachTestFixtures.now,
            relatedEventId: checkIn.id
        )
        XCTAssertEqual(SMARTGoalActivityLogic.netCheckInCount(in: [checkIn, undo]), 0)
        XCTAssertEqual(SMARTGoalActivityLogic.netCheckInCount(in: [checkIn]), 1)
    }

    func test_fallbackDoesNotCountTowardTheAcceptedTarget() {
        let goalId = UUID()
        let accepted = CoachTestFixtures.checkIn(goalId: goalId, occurredAt: CoachTestFixtures.now)
        let fallback = CoachTestFixtures.checkIn(
            goalId: goalId,
            occurredAt: CoachTestFixtures.now,
            countsTowardTarget: false
        )
        XCTAssertEqual(SMARTGoalActivityLogic.netCheckInCount(in: [accepted, fallback]), 1)
        XCTAssertEqual(SMARTGoalActivityLogic.activeFallbacks(in: [accepted, fallback]).count, 1)
        let lines = SMARTGoalActivityLogic.coachHistoryLines(
            for: [accepted, fallback],
            targetCount: 3,
            fallbackAction: "walk five minutes"
        )
        XCTAssertTrue(lines.contains { $0.contains("do not satisfy") || $0.contains("does not") || $0.contains("Not counted") || $0.contains("fallback") })
        XCTAssertFalse(lines.contains { $0.localizedCaseInsensitiveContains("streak") && !$0.contains("Do not") })
    }

    func test_duplicateClientEventIdsAreDetected() {
        let goalId = UUID()
        let first = CoachTestFixtures.checkIn(
            goalId: goalId,
            occurredAt: CoachTestFixtures.now,
            clientEventId: "watch-1"
        )
        XCTAssertTrue(SMARTGoalActivityLogic.alreadyProcessed(clientEventId: "watch-1", in: [first]))
        XCTAssertFalse(SMARTGoalActivityLogic.alreadyProcessed(clientEventId: "watch-2", in: [first]))
        XCTAssertFalse(SMARTGoalActivityLogic.alreadyProcessed(clientEventId: "", in: [first]))
    }

    func test_revisionIsAPlanChangeNotAnExtraCheckIn() {
        let previous = CoachTestFixtures.goal(target: 5, mask: 0b011)
        var current = previous
        current.targetCount = 3
        XCTAssertTrue(SMARTGoalActivityLogic.planChanged(from: previous, to: current))
        let revision = SMARTGoalActivity(
            goalId: previous.id,
            kind: .revision,
            source: .userEntry,
            occurredAt: CoachTestFixtures.now,
            revision: SMARTGoalRevisionSnapshot.from(previous)
        )
        XCTAssertEqual(
            SMARTGoalActivityLogic.netCheckInCount(in: [
                CoachTestFixtures.checkIn(goalId: previous.id, occurredAt: nil),
                CoachTestFixtures.checkIn(goalId: previous.id, occurredAt: nil),
                revision
            ]),
            2
        )
        let lines = SMARTGoalActivityLogic.coachHistoryLines(
            for: [revision],
            targetCount: 3,
            fallbackAction: ""
        )
        XCTAssertTrue(lines.contains { $0.contains("plan change") })
    }
}

@MainActor
final class SMARTGoalStoreActivityTests: XCTestCase {
    private var store: SMARTGoalStore!
    private var defaultsKey: String { SMARTGoalSchema.defaultsKey }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        super.tearDown()
    }

    func test_migrationPreservesGoalsAndLeavesLegacyCheckInsUndated() throws {
        UserDefaults.standard.set(1, forKey: defaultsKey)
        let container = AppDataSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let original = CoachTestFixtures.goal(target: 8, mask: 0b10000001)
        context.insert(SMARTGoalEntity(goal: original))
        try context.save()

        let store = SMARTGoalStore(modelContext: context)
        let saved = try XCTUnwrap(store.goals.first { $0.id == original.id })
        XCTAssertEqual(saved.filledCount, 2)
        XCTAssertEqual(saved.filledMask, 0b011)
        let events = store.activities(for: original.id)
        XCTAssertEqual(SMARTGoalActivityLogic.netCheckInCount(in: events), 2)
        XCTAssertTrue(events.allSatisfy { $0.occurredAt == nil })
        XCTAssertEqual(UserDefaults.standard.integer(forKey: defaultsKey), SMARTGoalSchema.currentVersion)
    }

    func test_delayedDuplicateWatchEventsDoNotCorruptCounts() throws {
        let container = AppDataSchema.makeContainer(inMemory: true)
        let store = SMARTGoalStore(modelContext: ModelContext(container))
        let goal = CoachTestFixtures.goal(target: 4)
        store.save(goal)

        let tapped = CoachTestFixtures.now.addingTimeInterval(-3600)
        let event = WatchCheckInEvent(eventId: UUID(), goalId: goal.id, createdAt: tapped)
        XCTAssertTrue(store.applyWatchEvent(event, receivedAt: CoachTestFixtures.now))
        XCTAssertFalse(store.applyWatchEvent(event, receivedAt: CoachTestFixtures.now.addingTimeInterval(120)))
        let saved = try XCTUnwrap(store.goals.first { $0.id == goal.id })
        XCTAssertEqual(saved.filledCount, 1)
        let recorded = try XCTUnwrap(store.activities(for: goal.id).first)
        XCTAssertEqual(recorded.occurredAt, tapped)
        XCTAssertNotEqual(recorded.recordedAt, recorded.occurredAt)
    }

    func test_undoAndCorrectionPreserveAccurateHistory() throws {
        let container = AppDataSchema.makeContainer(inMemory: true)
        let store = SMARTGoalStore(modelContext: ModelContext(container))
        let goal = CoachTestFixtures.goal(target: 3)
        store.save(goal)
        XCTAssertTrue(store.recordCheckIn(goalId: goal.id, source: .iPhone, occurredAt: nil))
        let undated = try XCTUnwrap(store.activities(for: goal.id).first)
        let supplied = CoachTestFixtures.now.addingTimeInterval(-86_400)
        XCTAssertTrue(store.correctOccurrence(eventId: undated.id, occurredAt: supplied))
        XCTAssertEqual(store.goals.first?.filledCount, 1)
        XCTAssertEqual(store.activities(for: goal.id).first { $0.id == undated.id }?.occurredAt, supplied)
        XCTAssertTrue(store.undo(eventId: undated.id))
        XCTAssertEqual(store.goals.first?.filledCount, 0)
        XCTAssertTrue(store.activities(for: goal.id).contains { $0.kind == .undo })
    }

    func test_targetChangeIsStoredAsRevisionNotACheckIn() throws {
        let container = AppDataSchema.makeContainer(inMemory: true)
        let store = SMARTGoalStore(modelContext: ModelContext(container))
        let goal = CoachTestFixtures.goal(target: 5, mask: 0)
        store.save(goal)
        XCTAssertTrue(store.recordCheckIn(goalId: goal.id, source: .iPhone, occurredAt: CoachTestFixtures.now))
        var edit = SMARTGoalEdit(goal: store.goals[0], now: CoachTestFixtures.now)
        edit.targetCount = 4
        let saved = try store.saveReviewed(edit)
        XCTAssertEqual(saved.targetCount, 4)
        XCTAssertEqual(saved.filledCount, 1)
        XCTAssertTrue(store.activities(for: goal.id).contains { $0.kind == .revision })
        XCTAssertEqual(SMARTGoalActivityLogic.netCheckInCount(in: store.activities(for: goal.id)), 1)
    }

    func test_goalProposalDoesNotWriteUntilSaveReviewed() throws {
        let container = AppDataSchema.makeContainer(inMemory: true)
        let store = SMARTGoalStore(modelContext: ModelContext(container))
        let goal = CoachTestFixtures.goal(target: 5)
        store.save(goal)
        let proposal = try XCTUnwrap(CoachGoalProposal.make(
            operation: "update",
            goalID: goal.id.uuidString,
            specificText: "walk for five minutes after lunch",
            targetCount: 4,
            theme: nil,
            daysFromToday: nil,
            goals: store.goals,
            now: CoachTestFixtures.now
        ))
        XCTAssertEqual(store.goals.first?.specificText, goal.specificText)
        XCTAssertEqual(store.goals.first?.targetCount, 5)
        let saved = try store.saveReviewed(proposal.edit)
        XCTAssertEqual(saved.specificText, "walk for five minutes after lunch")
        XCTAssertEqual(saved.targetCount, 4)
    }

    func test_unpauseResumesWithoutInventingProgress() throws {
        let container = AppDataSchema.makeContainer(inMemory: true)
        let store = SMARTGoalStore(modelContext: ModelContext(container))
        store.save(CoachTestFixtures.goal(status: .paused))
        var edit = SMARTGoalEdit(goal: store.goals[0], now: CoachTestFixtures.now)
        edit.status = .active
        let saved = try store.saveReviewed(edit)
        XCTAssertEqual(saved.status, .active)
        XCTAssertEqual(saved.filledCount, 0)
    }

    func test_editMergesAConcurrentCheckInFromEvents() throws {
        let container = AppDataSchema.makeContainer(inMemory: true)
        let store = SMARTGoalStore(modelContext: ModelContext(container))
        let goal = CoachTestFixtures.goal(target: 5)
        store.save(goal)
        var edit = SMARTGoalEdit(goal: store.goals[0], now: CoachTestFixtures.now)
        edit.specificText = "walk after breakfast"
        XCTAssertTrue(store.recordCheckIn(goalId: goal.id, source: .watch, occurredAt: CoachTestFixtures.now))
        let saved = try store.saveReviewed(edit)
        XCTAssertEqual(saved.specificText, "walk after breakfast")
        XCTAssertEqual(saved.filledCount, 1)
    }

    func test_fallbackDoesNotSatisfyTheAcceptedPlan() {
        let container = AppDataSchema.makeContainer(inMemory: true)
        let store = SMARTGoalStore(modelContext: ModelContext(container))
        var plan = SMARTGoalPlan()
        plan.fallbackAction = "walk five minutes"
        let goal = CoachTestFixtures.goal(target: 3, plan: plan)
        store.save(goal)
        XCTAssertTrue(store.recordFallback(goalId: goal.id))
        XCTAssertEqual(store.goals.first?.filledCount, 0)
        XCTAssertEqual(SMARTGoalActivityLogic.activeFallbacks(in: store.activities(for: goal.id)).count, 1)
    }

    func test_pausedExpiredAndCompleteGoalsSkipNewCheckIns() {
        let container = AppDataSchema.makeContainer(inMemory: true)
        let store = SMARTGoalStore(modelContext: ModelContext(container))
        let paused = CoachTestFixtures.goal(status: .paused)
        store.save(paused)
        XCTAssertFalse(store.recordCheckIn(goalId: paused.id, source: .iPhone, occurredAt: Date()))
        let ended = CoachTestFixtures.goal(status: .ended, endDate: CoachTestFixtures.now.addingTimeInterval(-60))
        store.save(ended)
        XCTAssertFalse(store.recordCheckIn(goalId: ended.id, source: .iPhone, occurredAt: Date()))
    }
}
