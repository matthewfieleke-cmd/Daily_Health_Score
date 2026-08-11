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

    func generateDailyCard(
        snapshot: CoachSnapshot,
        profile: CoachUserProfile,
        summary: String
    ) async throws -> DailyCoachCardContent {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            let session = LanguageModelSession(instructions: CoachCharter.instructions)
            let knowledge = LifestyleMedicineKnowledge.promptBlock(
                query: snapshot.primaryFocus.rawValue,
                topics: LifestyleMedicineKnowledge.topics(for: snapshot.primaryFocus),
                limit: 2,
                characterBudget: 800
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
        profile: CoachUserProfile,
        summary: String,
        recentTurns: [CoachChatTurn]
    ) async throws -> (message: String, profileUpdate: CoachUserProfile?) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            let session = LanguageModelSession(instructions: CoachCharter.instructions)
            let transcript = Self.transcriptBlock(recentTurns)
            let healthBlock = snapshot?.promptBlock ?? "No live daily record is available right now. Do not invent personal metrics; answer from general Lifestyle Medicine knowledge."
            let directives = snapshot?.coachingDirective ?? "No metric directives available."
            var topics = intent.knowledgeTopics
            if let snapshot {
                topics += LifestyleMedicineKnowledge.topics(for: snapshot.primaryFocus)
            }
            // The on-device context window is small, so education questions get the
            // biggest slice of reference material and other intents stay lean.
            let knowledge = LifestyleMedicineKnowledge.promptBlock(
                query: userMessage,
                topics: topics,
                limit: intent == .education ? 4 : 2,
                characterBudget: intent == .education ? 1500 : 900
            )
            func makePrompt(compact: Bool) -> String {
                """
                Continue the DHS Lifestyle Coach conversation.

                USER MESSAGE:
                \(userMessage)

                DETECTED INTENT: \(intent.rawValue)

                \(intent.contract)

                HEALTH SNAPSHOT (authoritative numbers):
                \(healthBlock)

                COACHING DIRECTIVES (derived from goal status — follow these):
                \(directives)

                REFERENCE MATERIAL (authoritative content — use it to answer accurately):
                \(compact || knowledge.isEmpty ? "None retrieved; answer from general Lifestyle Medicine knowledge and stay non-diagnostic." : knowledge)

                USER PROFILE (informational only):
                \(compact ? "Omitted." : profile.promptBlock)

                RUNNING SUMMARY (informational only):
                \(compact || summary.isEmpty ? "None yet." : summary)

                RECENT TRANSCRIPT:
                \(compact || transcript.isEmpty ? "None yet." : transcript)

                Reply as the coach, following the response contract above. Do not repeat phrasing
                from the recent transcript. If the user stated a durable preference, constraint, or
                value, set shouldUpdateProfile true and fill only the relevant profile fields.
                Otherwise set shouldUpdateProfile false and leave the profile fields empty.
                """
            }

            let content: GenerableCoachChatReply
            do {
                content = try await session.respond(
                    to: makePrompt(compact: false),
                    generating: GenerableCoachChatReply.self
                ).content
            } catch {
                // The on-device context window is small. Retry once on a fresh
                // session with memory and reference material dropped.
                let retrySession = LanguageModelSession(instructions: CoachCharter.instructions)
                content = try await retrySession.respond(
                    to: makePrompt(compact: true),
                    generating: GenerableCoachChatReply.self
                ).content
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
            let transcript = recentTurns.map { turn in
                let label = turn.role == .user ? "User" : "Coach"
                return "\(label): \(turn.text)"
            }.joined(separator: "\n")
            let prompt = """
            Previous summary:
            \(previousSummary.isEmpty ? "None" : previousSummary)

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
    @Guide(description: "Coach reply that answers the user's question in its first sentence, written in second person, 3-6 sentences, no lists, headers, or emoji.")
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
