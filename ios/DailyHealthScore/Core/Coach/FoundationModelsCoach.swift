import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// DHS Lifestyle Coach on Apple Foundation Models: Private Cloud Compute when it
/// is available, the on-device model otherwise.
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

    /// Which model answered the last request, for the UI to surface.
    private(set) var lastTierUsed: CoachModelTier = .onDevice

    // MARK: - Check-in card

    func generateCheckIn(
        kind: CoachCheckInKind,
        snapshot: CoachSnapshot,
        memoryBlock: String,
        recentConversations: String,
        goalRows: [CoachCheckInGoalRow],
        trend: CoachTrendDigest?,
        goalPaceDirective: String?,
        now: Date = Date()
    ) async throws -> CoachCheckIn {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            let tier = CoachModelProvider.preferredTier()
            let budget = await CoachModelProvider.contextBudget(for: tier)
            let knowledge = LifestyleMedicineKnowledge.promptBlock(
                query: snapshot.primaryFocus.rawValue,
                topics: LifestyleMedicineKnowledge.topics(for: snapshot.primaryFocus),
                limit: 2,
                characterBudget: budget.knowledgeCharacters / 2
            )
            func makePrompt(budget: CoachContextBudget) -> String {
                """
                Write today's \(kind.title.lowercased()) card for the Home screen.

                HEALTH SNAPSHOT (authoritative):
                \(snapshot.promptBlock)

                COACHING DIRECTIVES (derived from goal status — follow these):
                \(snapshot.coachingDirective)

                SMART GOALS TODAY (already computed):
                \(CoachCheckInLogic.goalsBlock(goalRows))
                \(goalPaceDirective ?? "")

                \(trend?.promptBlock ?? "TREND FACTS: none today.")

                MEMORY FILES (what you know about this person; quote accurately):
                \(memoryBlock.limitedToCoachBudget(budget.profileCharacters))

                RECENT CONVERSATIONS (for the question; quote accurately):
                \(recentConversations.limitedToCoachBudget(budget.summaryCharacters))

                REFERENCE MATERIAL (authoritative content):
                \(knowledge.isEmpty ? "None." : knowledge)

                \(CoachCharter.checkInContract(kind: kind, hasTrend: trend != nil))
                """
            }
            let content: GenerableCoachCheckIn
            do {
                lastTierUsed = tier
                content = try await CoachModelProvider
                    .makeSession(tier: tier, instructions: CoachCharter.instructions)
                    .respond(to: makePrompt(budget: budget), generating: GenerableCoachCheckIn.self)
                    .content
            } catch where tier == .privateCloud {
                // Network loss, quota, or a server hiccup should never cost the
                // card; the on-device model can still write it.
                lastTierUsed = .onDevice
                let retryBudget = await CoachModelProvider.contextBudget(for: .onDevice)
                content = try await CoachModelProvider
                    .makeSession(tier: .onDevice, instructions: CoachCharter.instructions)
                    .respond(to: makePrompt(budget: retryBudget), generating: GenerableCoachCheckIn.self)
                    .content
            }
            let health = CoachMarkdown.plainText(content.healthLine).trimmedForCoach().endingOnSentence(maxCharacters: 220)
            guard !health.isEmpty else {
                throw CoachError.generationFailed("The coach returned an empty card.")
            }
            let question = CoachMarkdown.plainText(content.question).trimmedForCoach().endingOnSentence(maxCharacters: 200)
            let tomorrow = kind == .evening
                ? CoachMarkdown.plainText(content.tomorrowLine).trimmedForCoach().endingOnSentence(maxCharacters: 180)
                : ""
            let trendLine = trend != nil
                ? CoachMarkdown.plainText(content.trendLine).trimmedForCoach().endingOnSentence(maxCharacters: 220)
                : ""
            return CoachCheckIn(
                kind: kind,
                dateKey: snapshot.todayKey,
                healthLine: health,
                question: question,
                tomorrowLine: tomorrow,
                trendLine: trendLine.isEmpty ? (trend?.sentence ?? "") : trendLine,
                isFallback: false,
                generatedAt: now
            )
        }
        #endif
        throw CoachError.unavailable(.unavailable)
    }

    // MARK: - Chat

    func reply(
        to userMessage: String,
        intent: CoachIntent,
        snapshot: CoachSnapshot?,
        historyBlock: String?,
        memoryBlock: String,
        recentTurns: [CoachChatTurn],
        goals: [SMARTGoal] = [],
        focusedGoalID: UUID? = nil,
        previousProposal: CoachGoalProposal? = nil,
        planningGoal: Bool = false,
        focus: CoachFocusContext? = nil,
        activitiesByGoal: [UUID: [SMARTGoalActivity]] = [:],
        context: CoachReplyContext
    ) async throws -> CoachReplyResult {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            let tier = CoachModelProvider.tier(for: intent)
            let isGoalConversation = planningGoal || context.thread?.kind == .goal || CoachGoalPlanning.isGoalConversation(
                message: userMessage, focusedGoalID: focusedGoalID, hasProposal: previousProposal != nil
            )
            let instructions = isGoalConversation ? CoachCharter.goalPlanningInstructions : CoachCharter.instructions
            let budget = CoachContextBudget.make(
                totalTokens: await CoachModelProvider.contextTokens(for: tier),
                instructionCharacters: instructions.count
            )
            lastTierUsed = tier
            let tools: [any Tool] = CoachSessionTools.make(
                snapshot: snapshot,
                goals: goals,
                memoryBlock: memoryBlock,
                recentConversations: context.recentConversations,
                activitiesByGoal: activitiesByGoal
            )
            let session = CoachModelProvider.makeSession(
                tier: tier,
                instructions: instructions,
                tools: tools
            )
            let healthBlock: String
            if let focus, focus.isHistorical {
                healthBlock = """
                \(focus.promptBlock)
                TODAY (only if the user asks about today; do not substitute it for the selected period):
                \(snapshot?.minimalBlock ?? "No live daily record is available right now.")
                """
            } else if let snapshot {
                if intent.usesFullMetrics || context.allowUnpromptedHealth {
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
                sleep, exercise, or score unless they asked about those numbers or this chat
                leads with numbers. Do not follow metric coaching directives.
                """
            case .planning:
                nextStepPolicy = """
                COACHING DIRECTIVES (use the numbers; never print status tokens):
                \(snapshot?.coachingDirective ?? "No metric directives available.")
                Speak like a person. At most two concrete options.
                """
            case .dataLookup, .education:
                if context.allowUnpromptedHealth {
                    nextStepPolicy = """
                    You may mention today's Health in one sentence if it helps. Do not
                    recap the dashboard. Never print status tokens.
                    """
                } else {
                    nextStepPolicy = """
                    NEXT STEP POLICY: This message did not ask for a plan. Do not offer a
                    suggestion, a next step, or an activity idea. Answer only what was asked.
                    """
                }
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
            let chatLine: String = {
                guard let thread = context.thread else { return "CHAT: new." }
                var parts = ["CHAT: \"\(thread.title)\""]
                switch thread.kind {
                case .conversation: break
                case .acquaintance: parts.append("(getting acquainted)")
                case .checkInReply: parts.append("(reply to a Home check-in)")
                case .goal: parts.append("(about a saved SMART goal)")
                }
                if !thread.contextNote.isEmpty { parts.append("— \(thread.contextNote.limitedToCoachBudget(300))") }
                return parts.joined(separator: " ")
            }()
            // Every block is sized against whichever model is answering, so the
            // on-device retry re-trims rather than reusing server-sized text.
            func makePrompt(compact: Bool, budget: CoachContextBudget, answeringTier: CoachModelTier) -> String {
                let memorySection = compact
                    ? "Omitted."
                    : memoryBlock.limitedToCoachBudget(budget.profileCharacters)
                let recentSection = compact
                    ? "Omitted."
                    : context.recentConversations.limitedToCoachBudget(budget.summaryCharacters)
                let acquaintance = context.isAcquaintance ? CoachCharter.acquaintanceContract : ""
                if isGoalConversation {
                    let goalContext = CoachGoalPlanning.context(
                        goals: goals, focusedGoalID: focusedGoalID ?? context.thread?.goalId, previousProposal: previousProposal,
                        activitiesByGoal: activitiesByGoal
                    ).limitedToCoachBudget(1800)
                    let dialogue = Self.transcriptBlock(
                        recentTurns, maxTurns: compact ? 3 : 8,
                        maxCharactersPerTurn: compact ? 200 : 320
                    )
                    return """
                    \(chatLine)
                    USER MESSAGE: \(userMessage.limitedToCoachBudget(1200))
                    \(CoachGoalPlanning.contract)
                    \(goalContext)
                    \(context.goalPaceDirective ?? "")
                    \(focus.map { $0.promptBlock.limitedToCoachBudget(500) } ?? "")
                    AVAILABLE HEALTH FACTS (only use when relevant):
                    \(snapshot?.metrics.map(\.sentence).joined(separator: "\n").limitedToCoachBudget(650) ?? "No Health record; goal planning is still available.")
                    MEMORY FILES (quote accurately):
                    \(memorySection)
                    RECENT CONVERSATION (drafts are unsaved until a save confirmation):
                    \(dialogue)
                    \(CoachCharter.outputContract)
                    Reply in message and supply a goalProposal only for a concrete plan.
                    Never invent past behavior. Set goalCheckIn only when they clearly said they did the action.
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

                \(CoachCharter.attentionContract(pillar: context.pillar, isNewChat: context.isFirstReply))
                Unprompted Health this turn: \(context.allowUnpromptedHealth ? "allowed, one sentence max" : "not allowed").
                \(chatLine)
                \(acquaintance)

                USER MESSAGE:
                \(userMessage)

                DETECTED INTENT: \(intent.rawValue)

                \(intent.contract)

                \(CoachCharter.answerDepthGuidance(for: answeringTier))

                HEALTH SNAPSHOT (authoritative numbers):
                \(healthBlock)\(historySection)\(focusSection)

                \(nextStepPolicy)
                \(context.goalPaceDirective ?? "")

                REFERENCE MATERIAL (authoritative content — use it to answer accurately):
                \(compact || knowledge.isEmpty ? "None retrieved; answer from general Lifestyle Medicine knowledge and stay non-diagnostic." : knowledge)

                MEMORY FILES (what you know about this person; quote accurately; you may add, update, or remove notes):
                \(memorySection)

                RECENT CONVERSATIONS (other chats, newest first; for callbacks only):
                \(recentSection)

                RECENT TRANSCRIPT (this chat):
                \(compact || transcript.isEmpty ? "None yet." : transcript)

                TOOLS: lookupTodayHealth, lookupSMARTGoals, lookupWhatWeRemember,
                searchLifestyleMedicine. Call them when a number, a saved goal, a personal
                note, or a Lifestyle Medicine fact would make the answer true. Do not call
                lookupTodayHealth for a feeling, a relationship, or a confession.

                \(CoachCharter.outputContract)

                Reply as the coach, following the response contract above. Your first sentence must
                answer the user's message. Never repeat a sentence or a suggestion that already
                appears in the recent transcript. Set goalProposal to nil unless they asked to build
                or change a SMART goal; for editable SMART goal planning, invite the user to say
                "help me formulate a SMART goal."
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
                    instructions: instructions,
                    tools: []
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
            let memoryUpdates = content.memoryUpdates.compactMap {
                CoachMemoryUpdate(operation: $0.operation, section: $0.section, text: $0.text, replaces: $0.replaces)
            }
            let checkIn = content.goalCheckIn.flatMap {
                CoachGoalCheckInRequest.make(goalID: $0.goalID, when: $0.when, note: $0.note, goals: goals)
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
            return CoachReplyResult(
                message: message,
                title: content.threadTitle,
                summary: content.threadSummary,
                pillar: CoachPillar(modelValue: content.pillar),
                memoryUpdates: memoryUpdates,
                goalCheckIn: checkIn,
                goalProposal: proposal,
                proposalRejected: isGoalConversation && content.goalProposal != nil && proposal == nil
            )
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
struct GenerableCoachCheckIn {
    @Guide(description: "One complete spoken sentence about today's health. No status tokens (BELOW GOAL, GOAL MET, NO DATA). No ellipses. Plain text.")
    var healthLine: String

    @Guide(description: "One question that shows you remember this person, tied to a memory note, a recent conversation, or a live goal. One sentence ending in a question mark. Plain text.")
    var question: String

    @Guide(description: "Evening only: one small specific thing for tomorrow, one sentence starting with Tomorrow. Empty string in the morning.")
    var tomorrowLine: String

    @Guide(description: "Only when TREND FACTS were provided: one sentence with plain numbers. Otherwise empty string.")
    var trendLine: String
}

@available(iOS 26.0, *)
@Generable
struct GenerableMemoryUpdate {
    @Guide(description: "add, update, or remove.")
    var operation: String

    @Guide(description: "aboutYou, people, patterns, helps, goals, routines, body, or checkIns.")
    var section: String

    @Guide(description: "The note, under 160 characters, third person, present tense. Empty for remove.")
    var text: String

    @Guide(description: "For update or remove: the existing note being replaced or removed, quoted as closely as possible. Empty for add.")
    var replaces: String
}

@available(iOS 26.0, *)
@Generable
struct GenerableGoalCheckIn {
    @Guide(description: "Exact goalID from CURRENT GOALS or the SMART goals lookup.")
    var goalID: String

    @Guide(description: "today or yesterday.")
    var when: String

    @Guide(description: "Short note in the person's words. Empty if none.")
    var note: String
}

@available(iOS 26.0, *)
@Generable
struct GenerableCoachChatReply {
    @Guide(description: "Coach reply that answers the user's message in its first sentence, in second person, with conviction and warmth. Usually 3-6 sentences; a substantive question supported by reference material may run longer. Light Markdown: **bold** at most twice, a short '-' list only for two to four options, a blank line between paragraphs. No headers, tables, or emoji.")
    var message: String

    @Guide(description: "Two to five Title Case words naming this chat like a note to self, for example Fiber at Dinner. No quotes, no trailing punctuation.")
    var threadTitle: String

    @Guide(description: "One third-person sentence on what this chat is about and where it stands.")
    var threadSummary: String

    @Guide(description: "One of: relationships, nutrition, sleep, activity, stress, hobbies, general.")
    var pillar: String

    @Guide(description: "Memory file edits learned in this exchange, at most four. Empty when nothing durable was learned. Never today's numbers.")
    var memoryUpdates: [GenerableMemoryUpdate]

    @Guide(description: "Only when the person clearly said they completed a saved SMART goal action today or yesterday. Nil otherwise.")
    var goalCheckIn: GenerableGoalCheckIn?

    @Guide(description: "An unsaved SMART goal draft to review. Nil for advice, questions, progress reports or unsafe requests.")
    var goalProposal: GenerableSMARTGoalProposal?
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
#endif

private extension String {
    func trimmedForCoach() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
