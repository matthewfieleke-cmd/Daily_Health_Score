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
        summary: String
    ) async throws -> DailyCoachCardContent {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            // The daily card is generated once per day, so it is worth the
            // server model when that is available.
            let tier = CoachModelProvider.isServerModelAvailable ? CoachModelTier.privateCloud : .onDevice
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

            USER PROFILE (informational only):
            \(profile.promptBlock)

            RUNNING SUMMARY (informational only):
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
        recentTurns: [CoachChatTurn]
    ) async throws -> (message: String, profileUpdate: CoachUserProfile?) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            let tier = CoachModelProvider.tier(for: intent)
            let budget = await CoachModelProvider.contextBudget(for: tier)
            lastTierUsed = tier
            let session = CoachModelProvider.makeSession(tier: tier, instructions: CoachCharter.instructions)
            let healthBlock: String
            if let snapshot {
                healthBlock = intent.usesFullMetrics ? snapshot.promptBlock : snapshot.minimalBlock
            } else {
                healthBlock = "No live daily record is available right now. Do not invent personal metrics; answer from general Lifestyle Medicine knowledge."
            }
            let nextStepPolicy: String
            if intent.allowsNextStep {
                nextStepPolicy = """
                COACHING DIRECTIVES (derived from goal status — follow these):
                \(snapshot?.coachingDirective ?? "No metric directives available.")
                """
            } else {
                nextStepPolicy = """
                NEXT STEP POLICY: This message did not ask for a plan. Do not offer a
                suggestion, a next step, or an activity idea. Answer only what was asked.
                """
            }
            var topics = intent.knowledgeTopics
            if let snapshot {
                topics += LifestyleMedicineKnowledge.topics(for: snapshot.primaryFocus)
            }
            // Every block is sized against whichever model is answering, so the
            // on-device retry re-trims rather than reusing server-sized text.
            func makePrompt(compact: Bool, budget: CoachContextBudget) -> String {
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
                return """
                Continue the DHS Lifestyle Coach conversation.

                USER MESSAGE:
                \(userMessage)

                DETECTED INTENT: \(intent.rawValue)

                \(intent.contract)

                HEALTH SNAPSHOT (authoritative numbers):
                \(healthBlock)\(historySection)

                \(nextStepPolicy)

                REFERENCE MATERIAL (authoritative content — use it to answer accurately):
                \(compact || knowledge.isEmpty ? "None retrieved; answer from general Lifestyle Medicine knowledge and stay non-diagnostic." : knowledge)

                USER PROFILE (informational only):
                \(compact ? "Omitted." : profile.promptBlock.limitedToCoachBudget(budget.profileCharacters))

                RUNNING SUMMARY (informational only):
                \(compact || summary.isEmpty ? "None yet." : summary.limitedToCoachBudget(budget.summaryCharacters))

                RECENT TRANSCRIPT:
                \(compact || transcript.isEmpty ? "None yet." : transcript)

                Reply as the coach, following the response contract above. Your first sentence must
                answer the user's message. Never repeat a sentence or a suggestion that already
                appears in the recent transcript. If the user stated a durable preference,
                constraint, or value, set shouldUpdateProfile true and fill only the relevant
                profile fields. Otherwise set shouldUpdateProfile false and leave them empty.
                """
            }

            let content: GenerableCoachChatReply
            do {
                content = try await session.respond(
                    to: makePrompt(compact: false, budget: budget),
                    generating: GenerableCoachChatReply.self
                ).content
            } catch {
                // One fallback covers every failure mode that matters: no network,
                // exhausted server quota, or context pressure. Retry on-device with
                // memory and reference material dropped. If that also fails the
                // cause is not size or reachability, so say something human.
                let retryBudget = await CoachModelProvider.contextBudget(for: .onDevice)
                let retrySession = CoachModelProvider.makeSession(
                    tier: .onDevice,
                    instructions: CoachCharter.instructions
                )
                lastTierUsed = .onDevice
                do {
                    content = try await retrySession.respond(
                        to: makePrompt(compact: tier == .onDevice, budget: retryBudget),
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
            return (message, profileUpdate)
        }
        #endif
        throw CoachError.unavailable(.unavailable)
    }

    func refreshRunningSummary(
        previousSummary: String,
        recentTurns: [CoachChatTurn]
    ) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            let session = LanguageModelSession(instructions: """
            You maintain a short running summary for DHS Lifestyle Coach.
            Write neutral, accepting, non-judgmental notes.
            Include themes, what helped, open threads, and emotional stance if relevant.
            Record anything the person said they would try, so it can be followed up on once.
            Exclude raw daily metric tables and diagnostic labels.
            Keep under 900 characters.
            """)
            // Summary refresh runs after every chat turn, so it stays on-device
            // rather than spending the daily server allowance on bookkeeping.
            let budget = await CoachModelProvider.contextBudget(for: .onDevice)
            let transcript = Self.transcriptBlock(
                recentTurns,
                maxTurns: budget.transcriptTurns,
                maxCharactersPerTurn: budget.transcriptCharactersPerTurn
            )
            let prompt = """
            Previous summary:
            \(previousSummary.isEmpty ? "None" : previousSummary.limitedToCoachBudget(budget.summaryCharacters))

            New turns:
            \(transcript)

            Write the updated running summary only.
            """
            let response = try await session.respond(
                to: prompt,
                generating: GenerableCoachSummary.self
            )
            return response.content.summary.trimmedForCoach()
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
    @Guide(description: "Coach reply that answers the user's question in its first sentence, written in second person. Usually 3-6 sentences; a substantive question supported by reference material may run to about 10. Plain prose, no lists, headers, or emoji.")
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
