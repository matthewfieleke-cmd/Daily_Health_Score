import XCTest
@testable import DailyHealthScore

final class CoachContextBudgetTests: XCTestCase {
    private let os26 = CoachContextBudget.make(totalTokens: 4096)
    private let os27 = CoachContextBudget.make(totalTokens: 8192)

    func test_largerWindowGetsMoreRoom() {
        XCTAssertGreaterThan(os27.knowledgeCharacters, os26.knowledgeCharacters)
        XCTAssertGreaterThan(os27.transcriptTurns, os26.transcriptTurns)
        XCTAssertGreaterThan(os27.summaryCharacters, os26.summaryCharacters)
    }

    func test_smallWindowKeepsWorkableFloors() {
        // Below roughly one full knowledge entry, retrieval degrades to a fragment.
        XCTAssertGreaterThanOrEqual(os26.knowledgeCharacters, 900)
        XCTAssertGreaterThanOrEqual(os26.transcriptTurns, 2)
        XCTAssertGreaterThan(os26.transcriptCharactersPerTurn, 120)
    }

    /// Every section full at once is the worst case; it still has to fit.
    func test_worstCasePromptFitsTheWindow() {
        for budget in [os26, os27] {
            let characters = CoachCharter.instructions.count
                + CoachContextBudget.scaffoldingCharacters
                + budget.knowledgeCharacters
                + budget.historyCharacters
                + budget.transcriptTurns * budget.transcriptCharactersPerTurn
                + budget.summaryCharacters
                + budget.profileCharacters
            let tokens = Int(Double(characters) / CoachContextBudget.charactersPerToken)
                + CoachContextBudget.reservedResponseTokens
            XCTAssertLessThanOrEqual(
                tokens,
                budget.totalTokens,
                "worst-case prompt overflows a \(budget.totalTokens)-token window"
            )
        }
    }

    func test_truncationRespectsBudgetAndPrefersWordBoundary() {
        XCTAssertEqual("short".limitedToCoachBudget(50), "short")
        let long = "the quick brown fox jumps over the lazy dog"
        XCTAssertLessThanOrEqual(long.limitedToCoachBudget(20).count, 20)
        XCTAssertTrue(long.limitedToCoachBudget(20).hasSuffix("…"))
    }
}
