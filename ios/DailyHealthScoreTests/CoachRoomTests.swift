import XCTest
@testable import DailyHealthScore

final class CoachRoomTests: XCTestCase {
    func test_classify_filesRelationshipAndNutritionTalk() {
        XCTAssertEqual(CoachThreadLogic.classify("I overeat when my wife and I have disagreements"), .relationships)
        XCTAssertEqual(CoachThreadLogic.classify("What should I eat for dinner to get more fiber"), .nutrition)
        XCTAssertEqual(CoachThreadLogic.classify("I slept four hours and feel wrecked"), .sleep)
        XCTAssertEqual(CoachThreadLogic.classify("I want to walk after work"), .activity)
        XCTAssertEqual(CoachThreadLogic.classify("I'm so anxious I can't sit still"), .stress)
        XCTAssertEqual(CoachThreadLogic.classify("I miss playing guitar"), .hobbies)
        XCTAssertEqual(CoachThreadLogic.classify("hello"), .inbox)
    }

    func test_inboxFilesAfterTwoTurns() {
        XCTAssertNil(
            CoachThreadLogic.filingDecision(room: .inbox, userTexts: ["hello"], latestUserText: "hello")
        )
        XCTAssertEqual(
            CoachThreadLogic.filingDecision(
                room: .inbox,
                userTexts: ["I keep waking up", "sleep is a mess"],
                latestUserText: "sleep is a mess"
            ),
            .sleep
        )
    }

    func test_refileWhenTalkLeavesTheDesk() {
        XCTAssertEqual(
            CoachThreadLogic.filingDecision(
                room: .sleep,
                userTexts: ["bad night", "then my wife and I had a fight"],
                latestUserText: "then my wife and I had a fight"
            ),
            .relationships
        )
        XCTAssertNil(
            CoachThreadLogic.filingDecision(
                room: .sleep,
                userTexts: ["still tired"],
                latestUserText: "still tired"
            )
        )
    }

    func test_titleRenamesFromUserWords() {
        let title = CoachThreadLogic.title(from: ["we argued after dinner"], room: .relationships)
        XCTAssertTrue(title.lowercased().contains("argued"))
        XCTAssertNotEqual(title, CoachRoom.sleep.label)
    }

    func test_oneActivePerRoom_parksThePrevious() {
        let now = Date()
        let older = CoachThread(room: .sleep, title: "Tuesday", status: .active, lastMessageAt: now.addingTimeInterval(-60))
        let parked = CoachThreadLogic.parkActive(in: .sleep, threads: [older], now: now)
        XCTAssertEqual(parked.first?.status, .parked)
    }

    func test_staleAfter36Hours() {
        let now = Date()
        let stale = CoachThread(
            room: .nutrition,
            title: "Lunch",
            status: .active,
            lastMessageAt: now.addingTimeInterval(-CoachThreadLogic.parkAfter - 10)
        )
        XCTAssertTrue(CoachThreadLogic.isStale(stale, now: now))
        XCTAssertEqual(CoachThreadLogic.parkStale([stale], now: now).first?.status, .parked)
    }

    func test_unpromptedHealthOncePerWindow() {
        XCTAssertTrue(
            CoachThreadLogic.shouldMentionHealth(
                room: .nutrition, alreadyMentionedInWindow: false, userAskedAboutNumbers: false
            )
        )
        XCTAssertFalse(
            CoachThreadLogic.shouldMentionHealth(
                room: .nutrition, alreadyMentionedInWindow: true, userAskedAboutNumbers: false
            )
        )
        XCTAssertFalse(
            CoachThreadLogic.shouldMentionHealth(
                room: .relationships, alreadyMentionedInWindow: false, userAskedAboutNumbers: false
            )
        )
        XCTAssertTrue(
            CoachThreadLogic.shouldMentionHealth(
                room: .relationships, alreadyMentionedInWindow: true, userAskedAboutNumbers: true
            )
        )
    }

    func test_metricFocusMapsToADesk() {
        let sleep = CoachFocusContext(feature: .sleep)
        XCTAssertEqual(CoachRoom.from(focus: sleep), .sleep)
        XCTAssertEqual(CoachRoom.from(focus: CoachFocusContext(feature: .fiber)), .nutrition)
        XCTAssertEqual(CoachRoom.from(focus: CoachFocusContext(feature: .exercise)), .activity)
    }

    func test_continuePrefersActive() {
        let parked = CoachThread(room: .hobbies, title: "Old", status: .parked, lastMessageAt: Date().addingTimeInterval(-100))
        let active = CoachThread(room: .sleep, title: "Now", status: .active, lastMessageAt: Date())
        XCTAssertEqual(CoachThreadLogic.continueThread(in: [parked, active])?.title, "Now")
    }
}
