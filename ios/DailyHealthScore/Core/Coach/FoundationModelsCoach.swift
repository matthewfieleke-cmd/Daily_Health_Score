import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device DHS Lifestyle Coach backed by Apple Foundation Models when available.
@MainActor
final class FoundationModelsCoach {
    enum CoachError: LocalizedError {
        case unavailable(CoachAvailabilityStatus)
        case generationFailed(String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let status):
                return status.guidance
            case .generationFailed(let message):
                return message
            }
        }
    }

    var availability: CoachAvailabilityStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return mapAvailability(SystemLanguageModel.default.availability)
        }
        #endif
        return .unavailable
    }

    /// Which model answered the last chat message, for the UI to surface.
    private(set) var lastTierUsed: CoachModelTier = .onDevice

    func generateDailyCard(
        snapshot: CoachSnapshot,
        profile: CoachUserProfile,
        summary: String,
        memoryBlock: String = ""
    ) async throws -> DailyCoachCardContent {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            let tier = CoachModelProvider.preferredTier()
            let budget = await CoachModelProvider.contextBudget(for: tier)
            let session = CoachModelProvider.makeSession(tier: tier, instructions: CoachCharter.instructions)
            let knowledge = LifestyleMedicineKnowledge.promptBlock(
                query: snapshot.primaryFocus.rawValue,
                topics: LifestyleMedicineKnowledge.topics(for: snapshot.primaryFocus),
                limit: 3,
                characterBudget: budget.knowledgeCharacters * 2 / 3
            )
            let prompt = """
            Create today's DHS Lifestyle Coach card from the live health snapshot.

            HEALTH SNAPSHOT (authoritative):
            \(snapshot.promptBlock)

            COACHING DIRECTIVES (derived from goal status — follow these):
            \(snapshot.coachingDirective)

            REFERENCE MATERIAL (authoritative content):
            \(knowledge.isEmpty ? "None." : knowledge)

            USER PROFILE (informational only; confirmed facts beat interpretations):
            \(memoryBlock.isEmpty ? profile.promptBlock : memoryBlock)

            RUNNING SUMMARY (informational only; do not restore deleted memories):
            \(summary.isEmpty ? "None yet." : summary)

            \(CoachCharter.dailyCardContract)
            """
            let content: GenerableDailyCoachCard
            do {
                content = try await session.respond(
                    to: prompt,
                    generating: GenerableDailyCoachCard.self
                ).content
            } catch where tier == .privateCloud {
                // Network loss, quota, or a server hiccup should never cost the
                // card; the on-device model can still write it.
                content = try await CoachModelProvider
                    .makeSession(tier: .onDevice, instructions: CoachCharter.instructions)
                    .respond(to: prompt, generating: GenerableDailyCoachCard.self)
                    .content
            }
            return DailyCoachCardContent(
                whereYouAre: content.whereYouAre.trimmedForCoach().endingOnSentence(maxCharacters: 340),
                nextMove: content.nextMove.trimmedForCoach().endingOnSentence(maxCharacters: 240)
            )
        }
        #endif
        throw CoachError.unavailable(.unavailable)
    }

    func reply(
        to userMessage: String,
        intent: CoachIntent,
        snapshot: CoachSnapshot?,
        historyBlock: String?,
        profile: CoachUserProfile,
        summary: String,
        recentTurns: [CoachChatTurn],
        goals: [SMARTGoal] = [],
        focusedGoalID: UUID? = nil,
        previousProposal: CoachGoalProposal? = nil,
        planningGoal: Bool = false,
        focus: CoachFocusContext? = nil,
        memoryBlock: String = "",
        activitiesByGoal: [UUID: [SMARTGoalActivity]] = [:]
    ) async throws -> (message: String, profileUpdate: CoachUserProfile?, goalProposal: CoachGoalProposal?, proposalRejected: Bool) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            let tier = CoachModelProvider.tier(for: intent)
            let isGoalConversation = planningGoal || CoachGoalPlanning.isGoalConversation(
                message: userMessage, focusedGoalID: focusedGoalID, hasProposal: previousProposal != nil
            )
            let instructions = isGoalConversation ? CoachCharter.goalPlanningInstructions : CoachCharter.instructions
            let budget = CoachContextBudget.make(
                totalTokens: await CoachModelProvider.contextTokens(for: tier),
                instructionCharacters: instructions.count
            )
            lastTierUsed = tier
            let session = CoachModelProvider.makeSession(tier: tier, instructions: instructions)
            let healthBlock: String
            if let focus, focus.isHistorical {
                healthBlock = """
                \(focus.promptBlock)
                TODAY (only if the user asks about today; do not substitute it for the selected period):
                \(snapshot?.minimalBlock ?? "No live daily record is available right now.")
                """
            } else if let snapshot {
                if intent.usesFullMetrics {
                    healthBlock = snapshot.promptBlock + """


                    CHAT PHRASING: Use these numbers as facts when the user asked about them.
                    Never print the tokens BELOW GOAL, GOAL MET, GOAL EXCEEDED, or NO DATA.
                    Speak like a person in the room.
                    """
                } else {
                    healthBlock = snapshot.minimalBlock
                }
            } else {
                healthBlock = "No live daily record is available right now. Do not invent personal metrics; answer from general Lifestyle Medicine knowledge."
            }
            let nextStepPolicy: String
            switch intent {
            case .support:
                nextStepPolicy = """
                LISTEN RULE: They shared a feeling, relationship, or pattern. Stay with that.
                Do not mention today's fiber, sleep, exercise, or score. Do not follow
                metric coaching directives. Validate first. One skill or one question —
                not a food plan and not a dashboard recap.
                """
            case .general:
                nextStepPolicy = """
                LISTEN RULE: Answer what they actually said. Do not mention today's fiber,
                sleep, exercise, or score unless they asked about those numbers. Do not
                follow metric coaching directives.
                """
            case .planning:
                nextStepPolicy = """
                COACHING DIRECTIVES (use the numbers; never print status tokens):
                \(snapshot?.coachingDirective ?? "No metric directives available.")
                Speak like a person. At most two concrete options.
                """
            default:
                nextStepPolicy = """
                NEXT STEP POLICY: This message did not ask for a plan. Do not offer a
                suggestion, a next step, or an activity idea. Answer only what was asked.
                """
            }
            let topics = LifestyleMedicineKnowledge.retrievalTopics(
                intent: intent,
                query: userMessage,
                primaryFocus: snapshot?.primaryFocus
            )
            // Every block is sized against whichever model is answering, so the
            // on-device retry re-trims rather than reusing server-sized text.
            func makePrompt(compact: Bool, budget: CoachContextBudget, answeringTier: CoachModelTier) -> String {
                if isGoalConversation {
                    let goalContext = CoachGoalPlanning.context(
                        goals: goals, focusedGoalID: focusedGoalID, previousProposal: previousProposal,
                        activitiesByGoal: activitiesByGoal
                    ).limitedToCoachBudget(1800)
                    let dialogue = Self.transcriptBlock(
                        recentTurns, maxTurns: compact ? 3 : 6,
                        maxCharactersPerTurn: compact ? 200 : 300
                    )
                    return """
                    USER MESSAGE: \(userMessage.limitedToCoachBudget(1200))
                    \(CoachGoalPlanning.contract)
                    \(goalContext)
                    \(focus.map { $0.promptBlock.limitedToCoachBudget(500) } ?? "")
                    AVAILABLE HEALTH FACTS (only use when relevant):
                    \(snapshot?.metrics.map(\.sentence).joined(separator: "\n").limitedToCoachBudget(650) ?? "No Health record; goal planning is still available.")
                    USER MEMORY (confirmed facts vs interpretations):
                    \((memoryBlock.isEmpty ? profile.promptBlock : memoryBlock).limitedToCoachBudget(400))
                    RECENT CONVERSATION (drafts are unsaved until a save confirmation):
                    \(dialogue)
                    Reply in message and supply a goalProposal only for a concrete plan.
                    Set shouldUpdateProfile false unless the user shared a durable preference;
                    otherwise leave the profile fields empty. Never invent past behavior.
                    """
                }
                let transcript = Self.transcriptBlock(
                    recentTurns,
                    maxTurns: budget.transcriptTurns,
                    maxCharactersPerTurn: budget.transcriptCharactersPerTurn
                )
                // Education questions get the biggest slice of reference material;
                // other intents stay lean. Both scale with the context window.
                let knowledge = LifestyleMedicineKnowledge.promptBlock(
                    query: userMessage,
                    topics: topics,
                    limit: intent == .education ? 12 : 4,
                    characterBudget: intent == .education
                        ? budget.knowledgeCharacters
                        : budget.knowledgeCharacters * 2 / 3
                )
                // Only present when the user referenced an earlier day, so unrelated
                // questions never see a history section to riff on.
                let historySection = historyBlock.map {
                    """


                    EARLIER DAYS THE USER ASKED ABOUT (already computed — use these numbers exactly):
                    \($0.limitedToCoachBudget(budget.historyCharacters))
                    """
                } ?? ""
                let focusSection = focus.map {
                    """


                    \($0.promptBlock.limitedToCoachBudget(budget.historyCharacters))
                    """
                } ?? ""
                return """
                Continue the DHS Lifestyle Coach conversation.

                USER MESSAGE:
                \(userMessage)

                DETECTED INTENT: \(intent.rawValue)

                \(intent.contract)

                \(CoachCharter.chatHeartContract)
                \(CoachCharter.answerDepthGuidance(for: answeringTier))

                HEALTH SNAPSHOT (authoritative numbers):
                \(healthBlock)\(historySection)\(focusSection)

                \(nextStepPolicy)

                REFERENCE MATERIAL (authoritative content — use it to answer accurately):
                \(compact || knowledge.isEmpty ? "None retrieved; answer from general Lifestyle Medicine knowledge and stay non-diagnostic." : knowledge)

                USER MEMORY (informational only; confirmed facts beat interpretations; do not restore deleted notes):
                \(compact ? "Omitted." : (memoryBlock.isEmpty ? profile.promptBlock : memoryBlock).limitedToCoachBudget(budget.profileCharacters))

                RUNNING SUMMARY (informational only):
                \(compact || summary.isEmpty ? "None yet." : summary.limitedToCoachBudget(budget.summaryCharacters))

                RECENT TRANSCRIPT:
                \(compact || transcript.isEmpty ? "None yet." : transcript)

                Reply as the coach, following the response contract above. Your first sentence must
                answer the user's message. Never repeat a sentence or a suggestion that already
                appears in the recent transcript. If the user stated a durable preference,
                constraint, or value, set shouldUpdateProfile true and fill only the relevant
                profile fields. Otherwise set shouldUpdateProfile false and leave them empty.
                Set goalProposal to nil. For editable SMART goal planning, invite the user
                to choose "Build a goal with Coach" or ask to formulate a SMART goal.
                """
            }

            let content: GenerableCoachChatReply
            do {
                content = try await session.respond(
                    to: makePrompt(compact: false, budget: budget, answeringTier: tier),
                    generating: GenerableCoachChatReply.self
                ).content
            } catch {
                // One fallback covers every failure mode that matters: no network,
                // exhausted server quota, or context pressure. Retry on-device with
                // memory and reference material dropped. If that also fails the
                // cause is not size or reachability, so say something human.
                let retryBudget = CoachContextBudget.make(
                    totalTokens: await CoachModelProvider.contextTokens(for: .onDevice),
                    instructionCharacters: instructions.count
                )
                let retrySession = CoachModelProvider.makeSession(
                    tier: .onDevice,
                    instructions: instructions
                )
                lastTierUsed = .onDevice
                do {
                    content = try await retrySession.respond(
                        to: makePrompt(compact: tier == .onDevice, budget: retryBudget, answeringTier: .onDevice),
                        generating: GenerableCoachChatReply.self
                    ).content
                } catch {
                    throw CoachError.generationFailed(Self.friendlyFailureMessage)
                }
            }
            let message = content.message.trimmedForCoach()
            guard !message.isEmpty else {
                throw CoachError.generationFailed("The coach returned an empty reply.")
            }
            var profileUpdate: CoachUserProfile?
            if content.shouldUpdateProfile {
                let draft = CoachUserProfile(
                    preferredStyle: content.preferredStyle,
                    constraints: content.constraints,
                    nutritionNotes: content.nutritionNotes,
                    movementNotes: content.movementNotes,
                    sleepNotes: content.sleepNotes,
                    values: content.values,
                    whatHelps: content.whatHelps,
                    whatToAvoid: content.whatToAvoid
                )
                if !draft.isEmpty {
                    profileUpdate = draft
                }
            }
            let proposal = isGoalConversation ? content.goalProposal.flatMap { draft in
                CoachGoalProposal.make(
                    operation: draft.operation, goalID: draft.goalID,
                    specificText: draft.specificText, targetCount: draft.targetCount,
                    theme: draft.theme, daysFromToday: draft.daysFromToday, goals: goals,
                    focusedGoalID: focusedGoalID,
                    personalReason: draft.personalReason,
                    cue: draft.cue,
                    expectedBarriers: draft.expectedBarriers,
                    fallbackAction: draft.fallbackAction
                )
            } : nil
            return (message, profileUpdate, proposal, isGoalConversation && content.goalProposal != nil && proposal == nil)
        }
        #endif
        throw CoachError.unavailable(.unavailable)
    }

    func refreshRunningSummary(
        previousSummary: String,
        recentTurns: [CoachChatTurn],
        currentMemory: String = ""
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            let instructions = """
            You maintain a short running summary for DHS Lifestyle Coach.
            Write neutral, accepting, non-judgmental notes.
            Include themes, what helped, open threads, and emotional stance if relevant.
            Record anything the person said they would try, so it can be followed up on once.
            Exclude raw daily metric tables and diagnostic labels.
            Do not restore facts that are absent from CURRENT MEMORY. Deleted notes stay gone.
            Keep under 900 characters.
            """
            let tier = CoachModelProvider.preferredTier()
            let budget = await CoachModelProvider.contextBudget(for: tier)
            let transcript = Self.transcriptBlock(
                recentTurns,
                maxTurns: budget.transcriptTurns,
                maxCharactersPerTurn: budget.transcriptCharactersPerTurn
            )
            let prompt = """
            Previous summary:
            \(previousSummary.isEmpty ? "None" : previousSummary.limitedToCoachBudget(budget.summaryCharacters))

            CURRENT MEMORY (authoritative; do not restate deleted or contradicted notes):
            \(currentMemory.isEmpty ? "None" : currentMemory.limitedToCoachBudget(budget.profileCharacters))

            New turns:
            \(transcript)

            Write the updated running summary only.
            """
            let summary: String
            do {
                summary = try await CoachModelProvider
                    .makeSession(tier: tier, instructions: instructions)
                    .respond(to: prompt, generating: GenerableCoachSummary.self)
                    .content.summary.trimmedForCoach()
            } catch where tier == .privateCloud {
                summary = try await CoachModelProvider
                    .makeSession(tier: .onDevice, instructions: instructions)
                    .respond(to: prompt, generating: GenerableCoachSummary.self)
                    .content.summary.trimmedForCoach()
            }
            return summary
        }
        #endif
        throw CoachError.unavailable(.unavailable)
    }

    /// Shown instead of a raw framework error, which is usually a guardrail
    /// rejection rather than anything the person did wrong.
    static let friendlyFailureMessage = """
    I couldn't put a good answer together for that one. Try rephrasing it, \
    or ask me something else — I'm still here.
    """

    /// Keeps the transcript small; the on-device context window is shared with the
    /// charter, snapshot, and reference material.
    nonisolated static func transcriptBlock(
        _ turns: [CoachChatTurn],
        maxTurns: Int = 6,
        maxCharactersPerTurn: Int = 240
    ) -> String {
        turns.suffix(maxTurns).map { turn in
            let label = turn.role == .user ? "User" : "Coach"
            var text = turn.text
            if text.count > maxCharactersPerTurn {
                text = String(text.prefix(maxCharactersPerTurn)) + "…"
            }
            return "\(label): \(text)"
        }.joined(separator: "\n")
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func ensureAvailable() throws {
        let status = mapAvailability(SystemLanguageModel.default.availability)
        guard status == .available else {
            throw CoachError.unavailable(status)
        }
    }

    @available(iOS 26.0, *)
    private func mapAvailability(_ availability: SystemLanguageModel.Availability) -> CoachAvailabilityStatus {
        switch availability {
        case .available:
            return .available
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct GenerableDailyCoachCard {
    @Guide(description: "2-3 complete sentences summarizing today's score and sleep, fiber, and exercise versus goals. Use exact status words. No ellipses.")
    var whereYouAre: String

    @Guide(description: "1-2 complete sentences. One concrete action still possible from the current clock time. No ellipses. Do not suggest a window that has already passed.")
    var nextMove: String
}

@available(iOS 26.0, *)
@Generable
struct GenerableCoachChatReply {
    @Guide(description: "An unsaved SMART goal draft to review. Nil for advice, questions, progress reports or unsafe requests.")
    var goalProposal: GenerableSMARTGoalProposal?
    @Guide(description: "Coach reply that answers the user's question in its first sentence, written in second person, with conviction and warmth. Usually 3-6 sentences; a substantive question supported by reference material may run longer. Plain prose, no lists, headers, or emoji.")
    var message: String

    @Guide(description: "True only when the user stated a durable preference or constraint.")
    var shouldUpdateProfile: Bool

    var preferredStyle: String
    var constraints: String
    var nutritionNotes: String
    var movementNotes: String
    var sleepNotes: String
    var values: String
    var whatHelps: String
    var whatToAvoid: String
}

@available(iOS 26.0, *)
@Generable
struct GenerableSMARTGoalProposal {
    @Guide(description: "Exactly create or update.")
    var operation: String
    @Guide(description: "Exact goalID from CURRENT GOALS for update; nil for create. Never invent an ID.")
    var goalID: String?
    @Guide(description: "One specific action per check-in, at most 500 characters. Required for create; nil to preserve the action on update.")
    var specificText: String?
    @Guide(description: "Total target check-ins, 1 through 30, at least the recorded count. Required for create; nil to preserve on update.")
    var targetCount: Int?
    @Guide(description: "marriage, parenting, health, relationships, finances, career, or choresMisc. Required for create; nil to preserve on update.")
    var theme: String?
    @Guide(description: "Days from today until the deadline, 1 through 30. Required for create; nil for update unless a deadline change was requested.")
    var daysFromToday: Int?
    @Guide(description: "Optional personal reason. Nil to preserve on update.")
    var personalReason: String?
    @Guide(description: "Optional cue such as after lunch. Nil to preserve on update.")
    var cue: String?
    @Guide(description: "Optional expected barriers. Ask; do not invent. Nil to preserve on update.")
    var expectedBarriers: String?
    @Guide(description: "Optional smaller fallback that does not silently satisfy a larger accepted action.")
    var fallbackAction: String?
}

@available(iOS 26.0, *)
@Generable
struct GenerableCoachSummary {
    @Guide(description: "Updated running summary under 900 characters.")
    var summary: String
}
#endif

private extension String {
    func trimmedForCoach() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
