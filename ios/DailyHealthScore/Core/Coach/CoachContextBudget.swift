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
    /// Coach prompts run denser than prose — numbers, labels, field names — and
    /// a 4,096-token window overflowed by one token at 3.5, so this sits below
    /// the documented range on purpose.
    static let charactersPerToken = 3.0
    /// Window to assume when the framework cannot report one.
    static let fallbackTokenCapacity = 4096
    /// Fixed prompt scaffolding: snapshot, directives, contract, section headers,
    /// the shape note, a care note, and the intake contract when it applies.
    /// This reserve has to cover the fullest of those at once.
    static let scaffoldingCharacters = 4200

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
    static let safetyMarginTokens = 200

    let totalTokens: Int
    let responseTokens: Int
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
        // Shares sum to well under 1.0: every block being simultaneously full is
        // the worst case, and the small window has no room for an overrun.
        // Upper bounds are generous enough for the 32K server window without
        // letting a prompt grow past the point where more material helps.
        var history = clamp(Int(Double(available) * 0.15), min: 400, max: maxHistoryCharacters)
        var transcript = clamp(Int(Double(available) * 0.45), min: 480, max: 16_000)
        var summary = clamp(Int(Double(available) * 0.10), min: 300, max: 2_000)
        var profile = clamp(Int(Double(available) * 0.09), min: 260, max: 1_600)

        // Those floors can outrun a small window as the charter grows, and a
        // budget that promises more room than exists is how prompts get silently
        // truncated. Scale every block back together instead.
        let requested = history + transcript + summary + profile
        if requested > available {
            let scale = Double(available) / Double(requested)
            history = Swift.max(Int(Double(history) * scale), 200)
            transcript = Swift.max(Int(Double(transcript) * scale), 300)
            summary = Swift.max(Int(Double(summary) * scale), 150)
            profile = Swift.max(Int(Double(profile) * scale), 130)
        }

        let turns = clamp(transcript / 280, min: 2, max: maxTranscriptTurns)

        return CoachContextBudget(
            totalTokens: totalTokens,
            responseTokens: reservedResponseTokens(totalTokens: totalTokens),
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

    /// Keeps whole sentences inside the budget. A first sentence that itself
    /// does not fit is cut on a word, the same way a raw budget cut works.
    func limitedToCoachSentences(_ budget: Int) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > budget, budget > 1 else { return trimmed }
        let sentences = endingOnSentence(maxCharacters: budget)
        if !sentences.isEmpty, sentences.count <= budget {
            return sentences
        }
        return limitedToCoachBudget(budget)
    }
}
