import Foundation

/// Sizes each part of a coach prompt against the model's real context window
/// instead of hardcoded character caps.
///
/// The on-device window is 4,096 tokens on OS 26 and 8,192 on OS 27, so a fixed
/// budget either wastes half the window on newer systems or overflows on older
/// ones. Apple documents roughly three to four characters per token for English,
/// and this uses the conservative end of that range.
struct CoachContextBudget: Equatable, Sendable {
    /// Apple documents roughly three to four characters per token for English.
    static let charactersPerToken = 3.5
    /// Window to assume when the framework cannot report one.
    static let fallbackTokenCapacity = 4096
    /// Room held back for the model's own structured reply.
    static let reservedResponseTokens = 700
    /// Fixed prompt scaffolding: snapshot, directives, contract, section headers.
    static let scaffoldingCharacters = 2400

    let totalTokens: Int
    let knowledgeCharacters: Int
    let historyCharacters: Int
    let transcriptTurns: Int
    let transcriptCharactersPerTurn: Int
    let summaryCharacters: Int
    let profileCharacters: Int

    /// Characters available for everything the app adds to a prompt, after the
    /// charter instructions and the reserved response allowance.
    static func availablePromptCharacters(
        totalTokens: Int,
        instructionCharacters: Int
    ) -> Int {
        let usableTokens = max(totalTokens - reservedResponseTokens, 0)
        let usableCharacters = Int(Double(usableTokens) * charactersPerToken)
        return max(usableCharacters - instructionCharacters - scaffoldingCharacters, 1200)
    }

    static func make(
        totalTokens: Int,
        instructionCharacters: Int = CoachCharter.instructions.count
    ) -> CoachContextBudget {
        let available = availablePromptCharacters(
            totalTokens: totalTokens,
            instructionCharacters: instructionCharacters
        )

        // Shares of what's left, then clamped so a very large window does not
        // produce a rambling prompt and a small one still leaves room for facts.
        // The knowledge floor is one full reference entry; below that, retrieval
        // returns a fragment and the model answers from memory instead.
        // Shares sum to well under 1.0: every block being simultaneously full is
        // the worst case, and the small window has no room for an overrun.
        let knowledge = clamp(Int(Double(available) * 0.28), min: 900, max: 4200)
        let history = clamp(Int(Double(available) * 0.10), min: 400, max: 1400)
        let transcript = clamp(Int(Double(available) * 0.30), min: 480, max: 6000)
        let summary = clamp(Int(Double(available) * 0.10), min: 300, max: 1400)
        let profile = clamp(Int(Double(available) * 0.09), min: 260, max: 1200)

        let turns = clamp(transcript / 280, min: 2, max: 16)

        return CoachContextBudget(
            totalTokens: totalTokens,
            knowledgeCharacters: knowledge,
            historyCharacters: history,
            transcriptTurns: turns,
            transcriptCharactersPerTurn: max(transcript / turns, 120),
            summaryCharacters: summary,
            profileCharacters: profile
        )
    }

    private static func clamp(_ value: Int, min lower: Int, max upper: Int) -> Int {
        Swift.min(Swift.max(value, lower), upper)
    }
}

extension String {
    /// Trims to a character budget on a word boundary where possible.
    func limitedToCoachBudget(_ budget: Int) -> String {
        guard count > budget, budget > 1 else { return self }
        let cut = prefix(budget - 1)
        if let lastSpace = cut.lastIndex(of: " "), cut.distance(from: cut.startIndex, to: lastSpace) > budget / 2 {
            return String(cut[..<lastSpace]) + "…"
        }
        return String(cut) + "…"
    }
}
