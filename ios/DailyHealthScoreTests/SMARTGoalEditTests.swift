import XCTest
@testable import DailyHealthScore

final class SMARTGoalEditTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func goal(target: Int = 5, mask: Int = 0b00101) -> SMARTGoal {
        SMARTGoal(
            id: UUID(), specificText: "walk for ten minutes after lunch",
            targetCount: target, relevantTheme: .health, timeWindowDays: 7,
            endDate: now.addingTimeInterval(3 * 86_400 + 123),
            createdAt: now.addingTimeInterval(-4 * 86_400),
            generatedSummary: "Original summary", filledMask: mask, status: .active,
            remindersEnabled: true, reminderHour: 18, reminderMinute: 35,
            reminderWeekdaysMask: 0b0101010
        )
    }

    func test_editPreservesIdentityExactDeadlineAndReminderSettings() throws {
        let original = goal()
        var edit = SMARTGoalEdit(goal: original, now: now)
        edit.specificText = "  walk for five minutes after lunch  "
        let saved = try edit.build(latest: original, now: now)

        XCTAssertEqual(saved.id, original.id)
        XCTAssertEqual(saved.createdAt, original.createdAt)
        XCTAssertEqual(saved.endDate, original.endDate)
        XCTAssertEqual(saved.timeWindowDays, original.timeWindowDays)
        XCTAssertEqual(saved.filledMask, original.filledMask)
        XCTAssertEqual(saved.remindersEnabled, original.remindersEnabled)
        XCTAssertEqual(saved.reminderHour, 18)
        XCTAssertEqual(saved.reminderMinute, 35)
        XCTAssertEqual(saved.reminderWeekdaysMask, 0b0101010)
        XCTAssertEqual(saved.specificText, "walk for five minutes after lunch")
        XCTAssertTrue(saved.generatedSummary.contains(saved.specificText))
        XCTAssertFalse(saved.generatedSummary.contains("within 7 days"))
    }

    func test_editMergesAWatchCheckInReceivedAfterOpeningTheEditor() throws {
        let original = goal()
        var edit = SMARTGoalEdit(goal: original, now: now)
        edit.relevantTheme = .relationships
        var live = original
        XCTAssertTrue(live.fillNextEmpty())

        let saved = try edit.build(latest: live, now: now)
        XCTAssertEqual(saved.filledMask, live.filledMask)
        XCTAssertEqual(saved.filledCount, 3)
        XCTAssertEqual(saved.relevantTheme, .relationships)
    }

    func test_reducingTargetPreservesSparseCheckInsBeyondTheNewCircleCount() throws {
        let original = goal(target: 8, mask: 0b10000001)
        var edit = SMARTGoalEdit(goal: original, now: now)
        edit.targetCount = 3

        let saved = try edit.build(latest: original, now: now)
        XCTAssertEqual(saved.targetCount, 3)
        XCTAssertEqual(saved.filledCount, 2)
        XCTAssertEqual(saved.filledMask, 0b011)
    }

    func test_liveProgressCannotBeDiscardedByReducingTheTarget() {
        let original = goal()
        var edit = SMARTGoalEdit(goal: original, now: now)
        edit.targetCount = 2
        var live = original
        live.fillNextEmpty()

        XCTAssertThrowsError(try edit.build(latest: live, now: now))
    }

    func test_staleEditorCannotResurrectADeletedGoalOrOverwriteAnotherEdit() {
        let original = goal()
        let edit = SMARTGoalEdit(goal: original, now: now)
        XCTAssertThrowsError(try edit.build(latest: nil, now: now))

        var live = original
        live.reminderMinute = 45
        XCTAssertThrowsError(try edit.build(latest: live, now: now))
    }

    func test_automaticExpiryDoesNotBlockAnEditAndAnExtensionReopensTheGoal() throws {
        var original = goal()
        original.endDate = now.addingTimeInterval(-60)
        var live = original
        live.status = .ended
        var edit = SMARTGoalEdit(goal: original, now: now)
        edit.specificText = "walk after breakfast"

        let ended = try edit.build(latest: live, now: now)
        XCTAssertEqual(ended.status, .ended)
        XCTAssertEqual(ended.endDate, original.endDate)

        edit.endDate = now.addingTimeInterval(2 * 86_400)
        let reopened = try edit.build(latest: live, now: now)
        XCTAssertEqual(reopened.status, .active)
        XCTAssertEqual(reopened.id, original.id)
        XCTAssertEqual(reopened.filledMask, original.filledMask)
    }

    func test_completedGoalRemainsCompleteWhenItsTextIsEdited() throws {
        let original = goal(target: 3, mask: 0b111)
        var edit = SMARTGoalEdit(goal: original, now: now)
        edit.specificText = "walk with a friend"

        let saved = try edit.build(latest: original, now: now)
        XCTAssertTrue(saved.isComplete)
        XCTAssertEqual(saved.filledCount, 3)
    }

    func test_newDraftStartsWithoutProgressAndCannotBeSavedTwice() throws {
        var edit = SMARTGoalEdit(now: now)
        edit.specificText = "call a friend"
        let saved = try edit.build(latest: nil, now: now)

        XCTAssertEqual(saved.id, edit.id)
        XCTAssertEqual(saved.filledCount, 0)
        XCTAssertEqual(saved.createdAt, now)
        XCTAssertThrowsError(try edit.build(latest: saved, now: now))
    }

    func test_invalidActionDeadlineAndReminderDaysAreRejected() {
        var edit = SMARTGoalEdit(now: now)
        XCTAssertThrowsError(try edit.build(latest: nil, now: now))
        edit.specificText = "walk after lunch"
        edit.endDate = now
        XCTAssertThrowsError(try edit.build(latest: nil, now: now))
        edit.endDate = SMARTGoalLogic.endDate(createdAt: now, days: 30).addingTimeInterval(60)
        XCTAssertThrowsError(try edit.build(latest: nil, now: now))
        edit.endDate = now.addingTimeInterval(86_400)
        edit.remindersEnabled = true
        edit.reminderWeekdaysMask = 0
        XCTAssertThrowsError(try edit.build(latest: nil, now: now))
    }
}
