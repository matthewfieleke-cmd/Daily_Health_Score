import XCTest
@testable import DailyHealthScore

final class CoachNoteSelectionTests: XCTestCase {
    func test_selectorInstructionsAskForIdsOnly() {
        let instructions = CoachCharter.noteSelectionInstructions
        XCTAssertTrue(instructions.contains("would change"))
        XCTAssertTrue(instructions.contains("what is known"))
        XCTAssertFalse(instructions.lowercased().contains("do not"))
    }

    func test_replyRequestKeepsThePreviousSentence() {
        let request = CoachNoteSelection.replyRequest(
            message: "Who is that?",
            earlier: "My wife made soup.",
            situation: "This chat began from today's Home card."
        )
        XCTAssertTrue(request.contains("Who is that?"))
        XCTAssertTrue(request.contains("My wife made soup."))
        XCTAssertTrue(request.contains("Home card"))
        XCTAssertEqual(
            CoachNoteSelection.replyRequest(message: "  ", earlier: "", situation: ""),
            ""
        )
    }

    func test_homeCardRequestNamesTheMomentWithoutTodaysNumbers() {
        let room = CoachNoteSelection.homeCardRequest(clockLabel: "Sunday evening", weakestPillar: "Sleep")
        XCTAssertTrue(room.contains("Sunday evening"))
        XCTAssertTrue(room.contains("Sleep"))
        XCTAssertTrue(room.contains("already on screen"))
        XCTAssertFalse(room.contains("6.1"))
        let open = CoachNoteSelection.homeCardRequest(clockLabel: "Monday morning", weakestPillar: nil)
        XCTAssertTrue(open.contains("All three pillars have room"))
        XCTAssertFalse(open.contains("most room right now is"))
    }

    func test_idsKeepOrderAndDropBlanks() {
        XCTAssertEqual(
            CoachNoteSelection.normalizedIDs([" none ", "ABCDEF12", "abcdef12", "chat1 | summary", "chat1ab2", "n/a"]),
            ["abcdef12", "chat1", "chat1ab2"]
        )
        XCTAssertEqual(CoachNoteSelection.normalizedIDs(["none", "null", ""]), [])
    }

    func test_writerUsesOnlyTheChosenNotes() {
        let wife = CoachMemoryItem(category: .people, content: "Wife is Maureen.", provenance: .userStated)
        let work = CoachMemoryItem(category: .aboutYou, content: "Work: Family Medicine.", provenance: .userStated)
        let oats = CoachMemoryItem(category: .likes, content: "Likes oats.", provenance: .userStated)
        let chats = """
        - Today: "Patient confidence" — Felt more confident while seeing patients.
        - Yesterday: "Breakfast" — Compared two oat products.
        """
        let block = CoachNoteSelection.writerBlock(
            chosenIDs: [String(wife.id.uuidString.prefix(8)), "chat1", "not-an-id"],
            items: [wife, work, oats],
            conversations: chats
        )
        XCTAssertTrue(block.hasPrefix("Saved notes:"))
        XCTAssertTrue(block.contains("Maureen"))
        XCTAssertTrue(block.contains("Patient confidence"))
        XCTAssertFalse(block.contains("Family Medicine"))
        XCTAssertFalse(block.contains("Likes oats"))
        XCTAssertFalse(block.contains("Breakfast"))
        XCTAssertFalse(block.contains("PEOPLE"))
        XCTAssertEqual(
            CoachNoteSelection.writerBlock(chosenIDs: ["none"], items: [wife]),
            ""
        )
    }

    func test_writerHonorsTheLimit() {
        let items = (0 ..< 6).map {
            CoachMemoryItem(category: .likes, content: "Staple \($0).", provenance: .userStated)
        }
        let ids = items.map { String($0.id.uuidString.prefix(8)) }
        let block = CoachNoteSelection.writerBlock(chosenIDs: ids, items: items, limit: 2)
        let lines = block.split(separator: "\n").filter { $0.contains("Staple") }
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("Staple 0"))
        XCTAssertTrue(lines[1].contains("Staple 1"))
    }

    func test_indexKeepsADurableNoteWhenRecentIsLong() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let person = CoachMemoryItem(
            category: .people,
            content: "Wife is Maureen.",
            provenance: .userStated,
            createdAt: now
        )
        let recent = (0 ..< 12).map { index in
            CoachMemoryItem(
                category: .checkIns,
                content: "Recent detail \(index) " + String(repeating: "snack ", count: 80),
                provenance: .userStated,
                createdAt: now.addingTimeInterval(TimeInterval(index))
            )
        }
        let index = CoachNoteSelection.index(
            items: [person] + recent,
            conversations: "- Today: \"Soup\" — Talked about dinner.",
            at: now,
            characterBudget: 400
        )
        XCTAssertTrue(index.contains("Maureen"))
        XCTAssertTrue(index.contains("chat1"))
        XCTAssertFalse(index.contains("Recent detail 11"))
        XCTAssertNotEqual(index, CoachNoteSelection.emptyIndex)
        XCTAssertEqual(CoachNoteSelection.index(items: []), CoachNoteSelection.emptyIndex)
    }
}
