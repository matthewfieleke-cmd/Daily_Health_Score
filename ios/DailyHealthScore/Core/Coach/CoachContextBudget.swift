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
    /// Fixed prompt scaffolding: snapshot, directives, contract, section headers.
    /// The snapshot now also carries HRV and SMART goal status, so this reserve
    /// has to cover a fuller worst case than the three daily metrics alone.
    static let scaffoldingCharacters = 3200

    /// Ceilings any window can reach. Callers that build a block before knowing
    /// which model will answer use these, and the prompt trims to the real
    /// budget afterwards.
    static let maxHistoryCharacters = 3_000
    static let maxTranscriptTurns = 40

    /// Room held back for the model's own reply. A larger window should buy a
    /// fuller answer, not just a longer prompt.
    static func reservedResponseTokens(totalTokens: Int) -> Int {
        min(max(totalTokens / 6, 600), 1600)
    }

    /// Characters per token is an estimate, and filling a window to the last
    /// token means any text that runs denser than the estimate overflows.
    static let safetyMarginTokens = 120

    let totalTokens: Int
    let responseTokens: Int
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
        let usableTokens = max(
            totalTokens - reservedResponseTokens(totalTokens: totalTokens) - safetyMarginTokens,
            0
        )
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
        // Upper bounds are generous enough for the 32K server window without
        // letting a prompt grow past the point where more material helps.
        var knowledge = clamp(Int(Double(available) * 0.28), min: 900, max: 12_000)
        var history = clamp(Int(Double(available) * 0.10), min: 400, max: maxHistoryCharacters)
        var transcript = clamp(Int(Double(available) * 0.30), min: 480, max: 16_000)
        var summary = clamp(Int(Double(available) * 0.10), min: 300, max: 2_000)
        var profile = clamp(Int(Double(available) * 0.09), min: 260, max: 1_600)

        // Those floors can outrun a small window as the charter grows, and a
        // budget that promises more room than exists is how prompts get silently
        // truncated. Scale every block back together instead.
        let requested = knowledge + history + transcript + summary + profile
        if requested > available {
            let scale = Double(available) / Double(requested)
            knowledge = Swift.max(Int(Double(knowledge) * scale), 500)
            history = Swift.max(Int(Double(history) * scale), 200)
            transcript = Swift.max(Int(Double(transcript) * scale), 300)
            summary = Swift.max(Int(Double(summary) * scale), 150)
            profile = Swift.max(Int(Double(profile) * scale), 130)
        }

        let turns = clamp(transcript / 280, min: 2, max: maxTranscriptTurns)

        return CoachContextBudget(
            totalTokens: totalTokens,
            responseTokens: reservedResponseTokens(totalTokens: totalTokens),
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
