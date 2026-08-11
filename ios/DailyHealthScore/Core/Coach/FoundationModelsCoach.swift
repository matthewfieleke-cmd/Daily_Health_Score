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

    private static var cachedContextTokens: Int?

    /// The model's real context window: 4,096 tokens on OS 26, 8,192 on OS 27.
    /// Read once at runtime so newer systems automatically get a richer prompt.
    ///
    /// `contextSize` reports the model's own limit and throws when Apple
    /// Intelligence is unavailable, in which case the conservative window applies.
    static func contextTokenCapacity() async -> Int {
        if let cachedContextTokens { return cachedContextTokens }
        var resolved = CoachContextBudget.fallbackTokenCapacity
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let reported = try? await SystemLanguageModel.default.contextSize, reported > 0 {
                resolved = reported
            }
        }
        #endif
        cachedContextTokens = resolved
        return resolved
    }

    static func contextBudget() async -> CoachContextBudget {
        CoachContextBudget.make(totalTokens: await contextTokenCapacity())
    }

    func generateDailyCard(
        snapshot: CoachSnapshot,
        profile: CoachUserProfile,
        summary: String
    ) async throws -> DailyCoachCardContent {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            let budget = await Self.contextBudget()
            let session = LanguageModelSession(instructions: CoachCharter.instructions)
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
            let response = try await session.respond(
                to: prompt,
                generating: GenerableDailyCoachCard.self
            )
            let content = response.content
            return DailyCoachCardContent(
                acknowledgment: content.acknowledgment.trimmedForCoach(),
                whyItMatters: content.whyItMatters.trimmedForCoach(),
                nextStep: content.nextStep.trimmedForCoach()
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
            let budget = await Self.contextBudget()
            let session = LanguageModelSession(instructions: CoachCharter.instructions)
            let transcript = Self.transcriptBlock(
                recentTurns,
                maxTurns: budget.transcriptTurns,
                maxCharactersPerTurn: budget.transcriptCharactersPerTurn
            )
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
            // Education questions get the biggest slice of reference material;
            // other intents stay lean. Both scale with the real context window.
            let knowledge = LifestyleMedicineKnowledge.promptBlock(
                query: userMessage,
                topics: topics,
                limit: intent == .education ? 6 : 3,
                characterBudget: intent == .education
                    ? budget.knowledgeCharacters
                    : budget.knowledgeCharacters * 2 / 3
            )
            // Only present when the user actually referenced an earlier day, so
            // unrelated questions never see a history section to riff on.
            let historySection = historyBlock.map {
                """


                EARLIER DAYS THE USER ASKED ABOUT (already computed — use these numbers exactly):
                \($0.limitedToCoachBudget(budget.historyCharacters))
                """
            } ?? ""

            func makePrompt(compact: Bool) -> String {
                """
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
                    to: makePrompt(compact: false),
                    generating: GenerableCoachChatReply.self
                ).content
            } catch {
                // Most first-attempt failures are context pressure. Retry once on a
                // fresh session with memory and reference material dropped; if that
                // also fails the cause is not size, so say something human.
                let retrySession = LanguageModelSession(instructions: CoachCharter.instructions)
                do {
                    content = try await retrySession.respond(
                        to: makePrompt(compact: true),
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
            Exclude raw daily metric tables and diagnostic labels.
            Keep under 900 characters.
            """)
            let budget = await Self.contextBudget()
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
    @Guide(description: "Warm acceptance of where the person is today, 1-2 sentences.")
    var acknowledgment: String

    @Guide(description: "Why the relevant Lifestyle Medicine pillar matters now, 1-2 sentences.")
    var whyItMatters: String

    @Guide(description: "One concrete feasible next step, 1-2 sentences.")
    var nextStep: String
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
