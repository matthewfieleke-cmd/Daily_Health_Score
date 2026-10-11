import XCTest
@testable import DailyHealthScore

final class CoachMarkdownTests: XCTestCase {
    func test_paragraphsBulletsAndNumbersBecomeBlocks() {
        let text = """
        **Yes** — beans work tonight.

        Two ways to do it:
        - Half a cup of black beans on whatever you already planned.
        - A pear before bed.

        1. First
        2. Second
        """
        let blocks = CoachMarkdown.blocks(from: text)
        XCTAssertEqual(blocks.count, 4)
        XCTAssertEqual(blocks[0], .paragraph("**Yes** — beans work tonight."))
        XCTAssertEqual(blocks[1], .paragraph("Two ways to do it:"))
        XCTAssertEqual(blocks[2], .bullets([
            "Half a cup of black beans on whatever you already planned.",
            "A pear before bed."
        ]))
        XCTAssertEqual(blocks[3], .numbered([
            CoachMarkdownItem(text: "First"),
            CoachMarkdownItem(text: "Second")
        ]))
    }

    func test_numberedListKeepsCountingAroundNestedBullets() {
        let text = """
        1. Heart rate
        - Sunday: 77 bpm
        - Monday: 78 bpm

        1. Resting heart rate
        - Sunday: 63 bpm

        That is the shape of the week.
        """
        let blocks = CoachMarkdown.blocks(from: text)
        XCTAssertEqual(blocks.count, 2)
        guard case .numbered(let items) = blocks[0] else {
            return XCTFail("Expected one numbered list")
        }
        XCTAssertEqual(items.map(\.text), ["Heart rate", "Resting heart rate"])
        XCTAssertEqual(items[0].bullets, ["Sunday: 77 bpm", "Monday: 78 bpm"])
        XCTAssertEqual(items[1].bullets, ["Sunday: 63 bpm"])
        guard case .paragraph(let closing) = blocks[1] else {
            return XCTFail("A sentence ends the list")
        }
        XCTAssertEqual(closing, "That is the shape of the week.")
    }

    func test_headersFoldIntoBoldAndLinesWithoutBlankJoin() {
        let blocks = CoachMarkdown.blocks(from: "## Tonight\nOne line\nsecond line")
        XCTAssertEqual(blocks, [.paragraph("**Tonight**"), .paragraph("One line second line")])
    }

    func test_plainTextStripsMarkers() {
        let plain = CoachMarkdown.plainText("**Bold** start\n- item one\n* item two\n3. third\n# Head")
        XCTAssertEqual(plain, "Bold start\nitem one\nitem two\nthird\nHead")
    }

    func test_emptyAndWhitespaceProduceNoBlocks() {
        XCTAssertTrue(CoachMarkdown.blocks(from: "").isEmpty)
        XCTAssertTrue(CoachMarkdown.blocks(from: "\n\n  \n").isEmpty)
    }

    func test_bulletMarkersRequireContent() {
        XCTAssertNil(CoachMarkdown.bulletItem("- "))
        XCTAssertEqual(CoachMarkdown.bulletItem("• Eat"), "Eat")
        XCTAssertNil(CoachMarkdown.numberedItem("2026-09-19 was fine"))
        XCTAssertEqual(CoachMarkdown.numberedItem("12) twelve"), "twelve")
    }
}
