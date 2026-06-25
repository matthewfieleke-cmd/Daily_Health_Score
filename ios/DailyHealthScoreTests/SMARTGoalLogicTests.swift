import XCTest
@testable import DailyHealthScore

final class SMARTGoalLogicTests: XCTestCase {
    func test_relevantThemes_areInRequestedOrder() {
        XCTAssertEqual(
            SMARTRelevantTheme.allCases,
            [.marriage, .parenting, .health, .relationships, .finances, .career]
        )
    }

    func test_dayWindow_isClampedToSupportedRange() {
        XCTAssertEqual(SMARTGoalLogic.clampedDays(0), 1)
        XCTAssertEqual(SMARTGoalLogic.clampedDays(12), 12)
        XCTAssertEqual(SMARTGoalLogic.clampedDays(31), 30)
    }

    func test_targetCount_isClampedToSupportedRange() {
        XCTAssertEqual(SMARTGoalLogic.clampedTargetCount(0), 1)
        XCTAssertEqual(SMARTGoalLogic.clampedTargetCount(8), 8)
        XCTAssertEqual(SMARTGoalLogic.clampedTargetCount(31), 30)
    }

    func test_summaryUsesSpecificCountThemeAndDayWindow() {
        let endDate = Date(timeIntervalSince1970: 0)
        let summary = SMARTGoalLogic.buildSummary(
            specific: "call a friend",
            targetCount: 5,
            theme: .relationships,
            timeWindowDays: 12,
            endDate: endDate
        )

        XCTAssertTrue(summary.contains("call a friend"))
        XCTAssertTrue(summary.contains("5 times"))
        XCTAssertTrue(summary.contains("12 days"))
        XCTAssertTrue(summary.contains("relationships"))
    }

    func test_setFilled_canUncheckCompletedCheckIn() {
        var goal = SMARTGoal(
            id: UUID(),
            specificText: "yoga before work",
            targetCount: 4,
            relevantTheme: .health,
            timeWindowDays: 5,
            endDate: Date(timeIntervalSince1970: 0),
            createdAt: Date(timeIntervalSince1970: 0),
            generatedSummary: "",
            filledMask: 0,
            status: .active,
            remindersEnabled: false,
            reminderHour: 7,
            reminderMinute: 0,
            reminderWeekdaysMask: 0
        )

        goal.setFilled(2, filled: true)
        XCTAssertTrue(goal.isFilled(2))
        XCTAssertEqual(goal.filledCount, 1)

        goal.setFilled(2, filled: false)
        XCTAssertFalse(goal.isFilled(2))
        XCTAssertEqual(goal.filledCount, 0)
    }
}
