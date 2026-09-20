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
        XCTAssertEqual(blocks[3], .numbered(["First", "Second"]))
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
