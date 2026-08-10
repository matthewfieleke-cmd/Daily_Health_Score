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
            let prompt = """
            Create today's DHS Lifestyle Coach card from the live health snapshot.
            The charter is the source of truth. Profile and summary only inform tone/fit.

            HEALTH SNAPSHOT:
            \(snapshot.promptBlock)

            USER PROFILE (informational only):
            \(profile.promptBlock)

            RUNNING SUMMARY:
            \(summary.isEmpty ? "None yet." : summary)

            Return three fields:
            - acknowledgment: accept where they are today (1–2 sentences)
            - whyItMatters: brief Lifestyle Medicine meaning; mention connection/serving others only if it fits naturally (1–2 sentences)
            - nextStep: one concrete, feasible invitation (1–2 sentences)
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
        snapshot: CoachSnapshot?,
        profile: CoachUserProfile,
        summary: String,
        recentTurns: [CoachChatTurn]
    ) async throws -> (message: String, profileUpdate: CoachUserProfile?) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            try ensureAvailable()
            let session = LanguageModelSession(instructions: CoachCharter.instructions)
            let transcript = recentTurns.map { turn in
                let label = turn.role == .user ? "User" : "Coach"
                return "\(label): \(turn.text)"
            }.joined(separator: "\n")
            let healthBlock = snapshot?.promptBlock ?? "No live daily record is available right now. Still coach within Lifestyle Medicine using acceptance and general wellness education; do not invent personal metrics."
            let prompt = """
            Continue the DHS Lifestyle Coach conversation.
            Charter is source of truth. Profile/summary inform; they do not override the charter.
            You may provide general Lifestyle Medicine education when asked, still non-diagnostic.

            HEALTH SNAPSHOT:
            \(healthBlock)

            USER PROFILE (informational only):
            \(profile.promptBlock)

            RUNNING SUMMARY:
            \(summary.isEmpty ? "None yet." : summary)

            RECENT TRANSCRIPT:
            \(transcript.isEmpty ? "None yet." : transcript)

            USER MESSAGE:
            \(userMessage)

            Reply as the coach. If the user stated a durable preference, constraint, or value,
            set shouldUpdateProfile true and fill profile fields (only durable facts; leave
            unrelated fields empty). Otherwise shouldUpdateProfile false and leave profile fields empty.
            """
            let response = try await session.respond(
                to: prompt,
                generating: GenerableCoachChatReply.self
            )
            let content = response.content
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
    @Guide(description: "Supportive coach reply grounded in the charter.")
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
