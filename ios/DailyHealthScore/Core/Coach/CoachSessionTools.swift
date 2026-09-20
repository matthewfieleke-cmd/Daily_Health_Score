import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Live lookups the Private Cloud Compute session can call instead of guessing.
/// Payloads are built in Swift from the same stores the rest of the app uses.
enum CoachSessionTools {
    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    static func make(
        snapshot: CoachSnapshot?,
        goals: [SMARTGoal],
        memoryBlock: String,
        recentConversations: String,
        activitiesByGoal: [UUID: [SMARTGoalActivity]],
        bodyTrend: BodyTrend? = nil
    ) -> [any Tool] {
        let today = snapshot?.promptBlock ?? "No live daily record is available."
        let goalText = CoachGoalPlanning.context(
            goals: goals,
            focusedGoalID: nil,
            previousProposal: nil,
            activitiesByGoal: activitiesByGoal
        )
        let conversations = recentConversations.trimmingCharacters(in: .whitespacesAndNewlines)
        let person = [
            "MEMORY FILES:\n" + memoryBlock.trimmingCharacters(in: .whitespacesAndNewlines),
            conversations.isEmpty || conversations == "None yet." ? "" : "RECENT CONVERSATIONS:\n" + conversations
        ].filter { !$0.isEmpty }.joined(separator: "\n")
        return [
            CoachLookupTodayTool(payload: today),
            CoachLookupGoalsTool(payload: goalText.isEmpty ? "No SMART goals saved." : goalText),
            CoachLookupPersonTool(payload: person.isEmpty ? "No personal notes yet." : person),
            CoachSearchLifestyleTool(),
            CoachFoodLookupTool(),
            CoachEvidenceSearchTool(),
            CoachCalculatorTool(),
            CoachBodyTrendTool(payload: bodyTrend?.promptBlock ?? "No weight or height data has been shared from Apple Health.")
        ]
    }

    /// The names the prompt lists so the model knows what it can reach for.
    static let toolNames = "lookupFood, searchEvidence, calculate, lookupWeightTrend, lookupTodayHealth, lookupSMARTGoals, lookupWhatWeRemember, searchLifestyleMedicine"
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct CoachLookupTodayTool: Tool {
    let name = "lookupTodayHealth"
    let description = "Today's Daily Health Score, sleep, fiber, exercise, HRV, and computed goal status. Use only when the person asked about their numbers or a plan that needs them."
    let payload: String

    @Generable
    struct Arguments {
        @Guide(description: "Why today's numbers are needed.")
        var reason: String
    }

    func call(arguments: Arguments) async throws -> String {
        _ = arguments
        return payload
    }
}

@available(iOS 26.0, *)
struct CoachLookupGoalsTool: Tool {
    let name = "lookupSMARTGoals"
    let description = "Saved SMART goals, check-ins, deadlines, and cues. Use when the person asks how a goal is going or wants to change one."
    let payload: String

    @Generable
    struct Arguments {
        @Guide(description: "Which goal or check-in question you are answering.")
        var focus: String
    }

    func call(arguments: Arguments) async throws -> String {
        _ = arguments
        return payload
    }
}

@available(iOS 26.0, *)
struct CoachLookupPersonTool: Tool {
    let name = "lookupWhatWeRemember"
    let description = "What this person has told us that exercise science, nutrition, and behavioral psychology would keep: triggers, relationships, recovery, identity, constraints, and what helps."
    let payload: String

    @Generable
    struct Arguments {
        @Guide(description: "What about this person you need to recall.")
        var topic: String
    }

    func call(arguments: Arguments) async throws -> String {
        _ = arguments
        return payload
    }
}

@available(iOS 26.0, *)
struct CoachSearchLifestyleTool: Tool {
    let name = "searchLifestyleMedicine"
    let description = "Guideline-aligned Lifestyle Medicine facts (nutrition, activity, sleep, stress, connection, substances, behavior change). Search before inventing a number or a protocol."
    @Generable
    struct Arguments {
        @Guide(description: "The lifestyle question to look up.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let block = LifestyleMedicineKnowledge.promptBlock(
            query: arguments.query,
            topics: [],
            limit: 6,
            characterBudget: 3500
        )
        return block.isEmpty
            ? "No matching Lifestyle Medicine entry. Stay general and do not invent a protocol."
            : block
    }
}
#endif
