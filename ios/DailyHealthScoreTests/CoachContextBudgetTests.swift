import XCTest
@testable import DailyHealthScore

final class CoachContextBudgetTests: XCTestCase {
    private let os26 = CoachContextBudget.make(totalTokens: 4096)
    private let os27 = CoachContextBudget.make(totalTokens: 8192)
    private let server = CoachContextBudget.make(totalTokens: 32_768)

    func test_largerWindowGetsMoreRoom() {
        XCTAssertGreaterThan(os27.historyCharacters, os26.historyCharacters)
        XCTAssertGreaterThan(os27.transcriptTurns, os26.transcriptTurns)
        XCTAssertGreaterThan(os27.summaryCharacters, os26.summaryCharacters)
    }

    /// The Private Cloud Compute window is 32K; the caps have to leave room to
    /// use it or routing to the server model buys nothing.
    func test_serverWindowIsActuallyUsed() {
        XCTAssertGreaterThan(server.transcriptTurns, os27.transcriptTurns)
        XCTAssertEqual(server.transcriptTurns, CoachContextBudget.maxTranscriptTurns)
    }

    /// A bigger window should buy a fuller answer, not only a longer prompt.
    func test_largerWindowReservesMoreRoomForTheReply() {
        XCTAssertGreaterThan(os27.responseTokens, os26.responseTokens)
        XCTAssertGreaterThanOrEqual(os26.responseTokens, 600)
    }

    func test_smallWindowKeepsWorkableFloors() {
        XCTAssertGreaterThanOrEqual(os26.historyCharacters, 200)
        XCTAssertGreaterThanOrEqual(os26.transcriptTurns, 2)
        XCTAssertGreaterThanOrEqual(os26.transcriptCharactersPerTurn, 120)
    }

    /// The 4K window cannot hold the full charter plus every block at its
    /// preferred size. It has to give ground evenly rather than promise room
    /// that isn't there and let the prompt truncate somewhere unpredictable.
    func test_smallWindowScalesBlocksTogetherRatherThanOverflowing() {
        let blocks = os26.historyCharacters
            + os26.transcriptTurns * os26.transcriptCharactersPerTurn
            + os26.summaryCharacters
            + os26.profileCharacters
        let available = CoachContextBudget.availablePromptCharacters(
            totalTokens: 4096,
            instructionCharacters: CoachCharter.instructions.count
        )

        XCTAssertLessThanOrEqual(blocks, available)
        // A window with room to spare must not be scaled back at all.
        XCTAssertEqual(server.historyCharacters, CoachContextBudget.maxHistoryCharacters)
    }

    /// Filling a window to its last token means any text that tokenizes denser
    /// than the estimate overflows.
    func test_everyWindowKeepsHeadroom() {
        for budget in [os26, os27, server] {
            let characters = CoachCharter.instructions.count
                + CoachContextBudget.scaffoldingCharacters
                + budget.historyCharacters
                + budget.transcriptTurns * budget.transcriptCharactersPerTurn
                + budget.summaryCharacters
                + budget.profileCharacters
            let tokens = Int(Double(characters) / CoachContextBudget.charactersPerToken)
                + budget.responseTokens

            XCTAssertLessThanOrEqual(
                tokens,
                budget.totalTokens - CoachContextBudget.safetyMarginTokens / 2,
                "a \(budget.totalTokens)-token window is packed too tightly to be safe"
            )
        }
    }

    /// Every section full at once is the worst case; it still has to fit.
    func test_worstCasePromptFitsTheWindow() {
        for budget in [os26, os27, server] {
            let characters = CoachCharter.instructions.count
                + CoachContextBudget.scaffoldingCharacters
                + budget.historyCharacters
                + budget.transcriptTurns * budget.transcriptCharactersPerTurn
                + budget.summaryCharacters
                + budget.profileCharacters
            let tokens = Int(Double(characters) / CoachContextBudget.charactersPerToken)
                + budget.responseTokens
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

    func test_sentenceTrimKeepsWholeSentencesInsideTheBudget() {
        let prose = "Sleep is short. Movement is open. Fiber is still ahead today and this sentence is the one that should be cut."
        XCTAssertEqual(prose.limitedToCoachSentences(40), "Sleep is short. Movement is open.")
        let words = String(repeating: "alpha ", count: 30)
        let cut = words.limitedToCoachSentences(40)
        XCTAssertLessThanOrEqual(cut.count, 40)
        XCTAssertTrue(cut.hasSuffix("…"))
        XCTAssertEqual("short".limitedToCoachSentences(50), "short")
    }
}
