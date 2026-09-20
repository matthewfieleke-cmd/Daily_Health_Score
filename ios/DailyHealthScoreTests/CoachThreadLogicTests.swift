import XCTest
@testable import DailyHealthScore

final class CoachThreadLogicTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        calendar = cal
        // Saturday, September 19, 2026 at 2:00 PM.
        now = cal.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 14, minute: 0))!
    }

    // MARK: Pillars

    func test_pillarParsesModelTextAndLegacyStorage() {
        XCTAssertEqual(CoachPillar(modelValue: "Relationships"), .relationships)
        XCTAssertEqual(CoachPillar(modelValue: "physical activity"), .activity)
        XCTAssertEqual(CoachPillar(modelValue: "Hobbies & Interests"), .hobbies)
        XCTAssertEqual(CoachPillar(modelValue: "stress management"), .stress)
        XCTAssertEqual(CoachPillar(modelValue: ""), .general)
        XCTAssertEqual(CoachPillar(modelValue: "something else"), .general)
        XCTAssertEqual(CoachPillar(storageValue: "inbox"), .general)
        XCTAssertEqual(CoachPillar(storageValue: "sleep"), .sleep)
        XCTAssertEqual(CoachPillar(storageValue: "garbage"), .general)
    }

    func test_onlyNutritionSleepActivityLeadWithNumbers() {
        XCTAssertTrue(CoachPillar.nutrition.leadsWithNumbers)
        XCTAssertTrue(CoachPillar.sleep.leadsWithNumbers)
        XCTAssertTrue(CoachPillar.activity.leadsWithNumbers)
        XCTAssertFalse(CoachPillar.relationships.leadsWithNumbers)
        XCTAssertFalse(CoachPillar.general.leadsWithNumbers)
        XCTAssertEqual(CoachPillar.from(focus: CoachFocusContext(feature: .fiber)), .nutrition)
        XCTAssertEqual(CoachPillar.from(focus: CoachFocusContext(feature: .goal)), .general)
        XCTAssertEqual(CoachPillar.from(primaryFocus: .exercise), .activity)
    }

    // MARK: Titles and previews

    func test_provisionalTitleIsShortAndCapitalizedWithoutEllipsis() {
        let title = CoachThreadLogic.provisionalTitle(from: "my wife says I should set a smart goal for walking after dinner.")
        XCTAssertEqual(title, "My wife says I should set")
        XCTAssertFalse(title.contains("…"))
        XCTAssertEqual(CoachThreadLogic.provisionalTitle(from: "   "), "New chat")
        XCTAssertEqual(CoachThreadLogic.provisionalTitle(from: "hello?"), "Hello")
    }

    func test_sanitizedTitleCleansModelOutputAndRejectsJunk() {
        XCTAssertEqual(CoachThreadLogic.sanitizedTitle("\"Fiber at Dinner.\""), "Fiber at Dinner")
        XCTAssertEqual(CoachThreadLogic.sanitizedTitle("**Argument With Sarah**"), "Argument With Sarah")
        XCTAssertEqual(CoachThreadLogic.sanitizedTitle("  Sleep   After Travel \n"), "Sleep After Travel")
        XCTAssertNil(CoachThreadLogic.sanitizedTitle(""))
        XCTAssertNil(CoachThreadLogic.sanitizedTitle("New chat"))
        XCTAssertNil(CoachThreadLogic.sanitizedTitle("This is a whole sentence that runs on far too long to be a title"))
    }

    func test_previewStripsMarkdownAndStaysOneLine() {
        let preview = CoachThreadLogic.preview(from: "**Yes.** Beans at dinner.\n\n- one\n- two")
        XCTAssertEqual(preview, "Yes. Beans at dinner. one two")
        let long = CoachThreadLogic.preview(from: String(repeating: "word ", count: 60))
        XCTAssertTrue(long.hasSuffix("…"))
        XCTAssertLessThanOrEqual(long.count, CoachThreadLogic.previewCharacters + 1)
    }

    // MARK: Continue, grouping, time labels

    func test_continueCandidateIgnoresEmptyAndStaleChats() {
        let empty = CoachThread(title: "Empty", messageCount: 0, lastMessageAt: now)
        let stale = CoachThread(title: "Old", messageCount: 4, lastMessageAt: now.addingTimeInterval(-8 * 86_400))
        let fresh = CoachThread(title: "Fresh", messageCount: 2, lastMessageAt: now.addingTimeInterval(-3 * 86_400))
        XCTAssertEqual(CoachThreadLogic.continueCandidate(in: [empty, stale, fresh], now: now)?.title, "Fresh")
        XCTAssertNil(CoachThreadLogic.continueCandidate(in: [empty, stale], now: now))
        XCTAssertNil(CoachThreadLogic.continueCandidate(in: [], now: now))
    }

    func test_groupsFollowCalendarDays() {
        func thread(daysAgo: Int, hour: Int = 9) -> CoachThread {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            let at = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
            return CoachThread(title: "t", messageCount: 1, lastMessageAt: at)
        }
        XCTAssertEqual(CoachThreadLogic.group(for: thread(daysAgo: 0), now: now, calendar: calendar), .today)
        XCTAssertEqual(CoachThreadLogic.group(for: thread(daysAgo: 1), now: now, calendar: calendar), .yesterday)
        XCTAssertEqual(CoachThreadLogic.group(for: thread(daysAgo: 4), now: now, calendar: calendar), .thisWeek)
        XCTAssertEqual(CoachThreadLogic.group(for: thread(daysAgo: 6), now: now, calendar: calendar), .thisWeek)
        XCTAssertEqual(CoachThreadLogic.group(for: thread(daysAgo: 7), now: now, calendar: calendar), .earlier)
        XCTAssertEqual(CoachThreadLogic.group(for: thread(daysAgo: 40), now: now, calendar: calendar), .earlier)
    }

    func test_sectionsHideEmptyChatsAndKeepNewestFirst() {
        let a = CoachThread(title: "A", messageCount: 2, lastMessageAt: now.addingTimeInterval(-60))
        let b = CoachThread(title: "B", messageCount: 3, lastMessageAt: now.addingTimeInterval(-30))
        let empty = CoachThread(title: "Empty", messageCount: 0, lastMessageAt: now)
        let old = CoachThread(title: "Old", messageCount: 1, lastMessageAt: now.addingTimeInterval(-10 * 86_400))
        let sections = CoachThreadLogic.sections([a, old, empty, b], now: now, calendar: calendar)
        XCTAssertEqual(sections.map(\.group), [.today, .earlier])
        XCTAssertEqual(sections[0].threads.map(\.title), ["B", "A"])
        XCTAssertEqual(sections[1].threads.map(\.title), ["Old"])
    }

    func test_timeLabelsReadLikeMessages() {
        let earlierToday = now.addingTimeInterval(-3 * 3600)
        XCTAssertFalse(CoachThreadLogic.timeLabel(for: earlierToday, now: now, calendar: calendar).isEmpty)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(CoachThreadLogic.timeLabel(for: yesterday, now: now, calendar: calendar), "Yesterday")
        let threeDays = calendar.date(byAdding: .day, value: -3, to: now)!
        XCTAssertEqual(CoachThreadLogic.timeLabel(for: threeDays, now: now, calendar: calendar), "Wednesday")
        let lastMonth = calendar.date(byAdding: .day, value: -30, to: now)!
        XCTAssertTrue(CoachThreadLogic.timeLabel(for: lastMonth, now: now, calendar: calendar).contains("Aug"))
    }

    // MARK: Callbacks and health mentions

    func test_recentConversationsBlockSkipsOpenChatAndUnsummarized() {
        let open = CoachThread(title: "Open", messageCount: 2, lastMessageAt: now, summary: "Talking now.")
        let quiet = CoachThread(title: "Quiet", messageCount: 2, lastMessageAt: now.addingTimeInterval(-86_400))
        let summarized = CoachThread(
            title: "Argument With Sarah",
            messageCount: 6,
            lastMessageAt: now.addingTimeInterval(-3 * 86_400),
            summary: "Overate after a fight; trying a walk first."
        )
        let block = CoachThreadLogic.recentConversationsBlock(
            [open, quiet, summarized], excluding: open.id, now: now, calendar: calendar
        )
        XCTAssertTrue(block.contains("Argument With Sarah"))
        XCTAssertTrue(block.contains("3 days ago"))
        XCTAssertFalse(block.contains("Open"))
        XCTAssertFalse(block.contains("Quiet"))
        XCTAssertEqual(
            CoachThreadLogic.recentConversationsBlock([open], excluding: open.id, now: now, calendar: calendar),
            "None yet."
        )
    }

    func test_unpromptedHealthOncePerWindowOnlyWhereNumbersLead() {
        XCTAssertTrue(CoachThreadLogic.shouldMentionHealth(pillar: .nutrition, alreadyMentionedInWindow: false, userAskedAboutNumbers: false))
        XCTAssertFalse(CoachThreadLogic.shouldMentionHealth(pillar: .nutrition, alreadyMentionedInWindow: true, userAskedAboutNumbers: false))
        XCTAssertFalse(CoachThreadLogic.shouldMentionHealth(pillar: .relationships, alreadyMentionedInWindow: false, userAskedAboutNumbers: false))
        XCTAssertTrue(CoachThreadLogic.shouldMentionHealth(pillar: .relationships, alreadyMentionedInWindow: true, userAskedAboutNumbers: true))
    }

    func test_launchIdentitiesAreDistinct() {
        let goal = UUID()
        let ids = [
            CoachChatLaunch.chats.id,
            CoachChatLaunch.newChat.id,
            CoachChatLaunch.acquaint.id,
            CoachChatLaunch.replyToCheckIn.id,
            CoachChatLaunch.goal(goal).id,
            CoachChatLaunch.thread(goal).id,
            CoachChatLaunch.compose("hi").id
        ]
        XCTAssertEqual(Set(ids).count, ids.count)
    }
}
