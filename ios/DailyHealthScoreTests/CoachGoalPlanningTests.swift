import XCTest
@testable import DailyHealthScore

final class CoachGoalPlanningTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    private func goal(text: String = "walk after lunch", endsInDays: Int = 7) -> SMARTGoal {
        SMARTGoal(
            id: UUID(), specificText: text, targetCount: 5, relevantTheme: .health,
            timeWindowDays: 7, endDate: now.addingTimeInterval(Double(endsInDays) * 86_400),
            createdAt: now, generatedSummary: "Original summary", filledMask: 0b00101,
            status: .active, remindersEnabled: true, reminderHour: 16,
            reminderMinute: 20, reminderWeekdaysMask: 0b0101010
        )
    }

    private func update(
        _ goal: SMARTGoal, id: String? = nil, count: Int? = nil,
        days: Int? = nil, focus: UUID? = nil
    ) -> CoachGoalProposal? {
        CoachGoalProposal.make(
            operation: "update", goalID: id ?? goal.id.uuidString,
            specificText: nil, targetCount: count, theme: nil, daysFromToday: days,
            goals: [goal], focusedGoalID: focus, now: now
        )
    }

    func test_coachUpdatePreservesUnrequestedFieldsAndRequiresReviewBeforeWriting() throws {
        let original = goal()
        let proposal = try XCTUnwrap(update(original, count: 3))
        XCTAssertTrue(proposal.isUpdate)
        XCTAssertEqual(original.targetCount, 5)

        let saved = try proposal.edit.build(latest: original, now: now)
        XCTAssertEqual(saved.id, original.id)
        XCTAssertEqual(saved.targetCount, 3)
        XCTAssertEqual(saved.specificText, original.specificText)
        XCTAssertEqual(saved.endDate, original.endDate)
        XCTAssertEqual(saved.relevantTheme, original.relevantTheme)
        XCTAssertEqual(saved.filledMask, original.filledMask)
        XCTAssertEqual(saved.remindersEnabled, original.remindersEnabled)
        XCTAssertEqual(saved.reminderWeekdaysMask, original.reminderWeekdaysMask)
        XCTAssertEqual(saved.reminderHour, 16)
        XCTAssertEqual(saved.reminderMinute, 20)
    }

    func test_invalidOrWrongFocusedIDsCannotProduceAnUpdate() {
        let original = goal()
        XCTAssertNil(update(original, id: "invented-id"))
        XCTAssertNil(update(original, id: UUID().uuidString))
        XCTAssertNil(update(original, count: 3, focus: UUID()))
        XCTAssertNotNil(update(original, count: 3, focus: original.id))
    }

    func test_modelCannotReduceTargetBelowRecordedProgressOrUseOutOfRangeValues() {
        let original = goal()
        XCTAssertNil(update(original, count: 1))
        XCTAssertNil(update(original, count: 31))
        XCTAssertNil(update(original, days: 0))
        XCTAssertNil(update(original, days: 31))
    }

    func test_concreteNewGoalCanBeDraftedWithoutAnyHealthOrGoalRecords() throws {
        let proposal = try XCTUnwrap(CoachGoalProposal.make(
            operation: "create", goalID: nil,
            specificText: "walk for ten minutes after lunch", targetCount: 3,
            theme: "health", daysFromToday: 7, goals: [], now: now
        ))
        XCTAssertFalse(proposal.isUpdate)
        let saved = try proposal.edit.build(latest: nil, now: now)
        XCTAssertEqual(saved.specificText, "walk for ten minutes after lunch")
        XCTAssertEqual(saved.targetCount, 3)
        XCTAssertEqual(saved.filledCount, 0)
        XCTAssertFalse(saved.remindersEnabled)
        XCTAssertEqual(saved.endDate, SMARTGoalLogic.endDate(createdAt: now, days: 7))
    }

    func test_ambiguousAndUnsupportedModelDraftsAreRejected() {
        func proposal(action: String? = "walk", theme: String? = "health", days: Int? = 7, operation: String = "create") -> CoachGoalProposal? {
            CoachGoalProposal.make(
                operation: operation, goalID: nil, specificText: action,
                targetCount: 3, theme: theme, daysFromToday: days, goals: [], now: now
            )
        }
        XCTAssertNil(proposal(action: nil))
        XCTAssertNil(proposal(action: "   "))
        XCTAssertNil(proposal(action: String(repeating: "a", count: 501)))
        XCTAssertNil(proposal(theme: "unknown"))
        XCTAssertNil(proposal(days: nil))
        XCTAssertNil(proposal(operation: "delete"))
    }

    func test_goalDraftStillRejectsDeletionOrPlanChangesBeforeReviewIsSaved() throws {
        let original = goal()
        let proposal = try XCTUnwrap(update(original, count: 3))
        XCTAssertThrowsError(try proposal.edit.build(latest: nil, now: now))

        var live = original
        live.endDate = now.addingTimeInterval(86_400)
        XCTAssertThrowsError(try proposal.edit.build(latest: live, now: now))
    }

    func test_goalContextPrioritizesTheSelectedGoalEvenWhenItHasEnded() {
        let active = (1...5).map { goal(text: "active \($0)", endsInDays: $0) }
        var selected = goal(text: "selected earlier goal", endsInDays: -2)
        selected.status = .ended
        let context = CoachGoalPlanning.context(goals: active + [selected], focusedGoalID: selected.id, now: now)

        XCTAssertTrue(context.contains("SELECTED goalID=\(selected.id.uuidString)"))
        XCTAssertTrue(context.contains("selected earlier goal"))
        XCTAssertTrue(context.contains("2 more goals are not shown"))
        XCTAssertFalse(context.contains(active[4].id.uuidString))
        XCTAssertTrue(context.contains("ENDED"))
    }

    func test_contextDoesNotReconstructDeletedGoalsFromAnUnsavedDraft() throws {
        let original = goal()
        let draft = try XCTUnwrap(update(original, count: 3))
        let context = CoachGoalPlanning.context(
            goals: [], focusedGoalID: original.id, previousProposal: draft, now: now
        )
        XCTAssertTrue(context.contains("selected goal was deleted"))
        XCTAssertTrue(context.contains("UNSAVED DRAFT"))
        XCTAssertTrue(context.contains("without Health data"))
    }

    func test_goalCacheKeyChangesWithProgressAndPlanButNotInputOrder() {
        let first = goal()
        let second = goal(text: "call a friend")
        let key = CoachGoalPlanning.cacheKey(goals: [first, second])
        XCTAssertEqual(key, CoachGoalPlanning.cacheKey(goals: [second, first]))

        var changed = first
        changed.fillNextEmpty()
        XCTAssertNotEqual(key, CoachGoalPlanning.cacheKey(goals: [changed, second]))
        changed = first
        changed.endDate = changed.endDate.addingTimeInterval(60)
        XCTAssertNotEqual(key, CoachGoalPlanning.cacheKey(goals: [changed, second]))
    }
}
