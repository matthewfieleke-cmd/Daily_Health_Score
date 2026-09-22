import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Which model answers a given message.
enum CoachModelTier: String, Equatable, Codable, Sendable {
    /// Apple's server model on Private Cloud Compute: frontier-class breadth,
    /// a 32K context window, and reasoning. Needs a network, the managed
    /// Private Cloud Compute entitlement, and daily quota.
    case privateCloud
    /// The on-device model. Always available, private, offline, and much smaller.
    case onDevice

    /// Used until the framework reports the real window.
    var assumedContextTokens: Int {
        switch self {
        case .privateCloud: return 32_768
        case .onDevice: return CoachContextBudget.fallbackTokenCapacity
        }
    }
}

/// Chooses and builds the session for each request.
///
/// Chat, the daily card, and the running summary all use Private Cloud Compute
/// when that model is available. On-device is only the fallback for missing
/// entitlement, no network, quota, or a failed server request.
@MainActor
enum CoachModelProvider {
    private static var cachedContextTokens: [CoachModelTier: Int] = [:]

    /// Cloud first. `intent` is kept so call sites stay stable.
    static func tier(for intent: CoachIntent) -> CoachModelTier {
        preferredTier()
    }

    static func preferredTier() -> CoachModelTier {
        isServerModelAvailable ? .privateCloud : .onDevice
    }

    static func contextBudget(for tier: CoachModelTier) async -> CoachContextBudget {
        CoachContextBudget.make(
            totalTokens: await contextTokens(for: tier),
            instructionCharacters: CoachCharter.instructions(for: tier).count
        )
    }

    /// Cached so we do not ask the framework for the window on every message.
    static func contextTokens(for tier: CoachModelTier) async -> Int {
        if let cached = cachedContextTokens[tier] { return cached }
        let resolved = await readContextTokens(for: tier)
        cachedContextTokens[tier] = resolved
        return resolved
    }
}

#if canImport(FoundationModels)
@MainActor
extension CoachModelProvider {
    static var isServerModelAvailable: Bool {
        // Account assignment is not enough: the debug profile must include the
        // managed capability. If the model is not usable, stay on-device.
        guard case .available = PrivateCloudComputeLanguageModel().availability else { return false }
        return !isServerQuotaExhausted
    }

    static var isServerQuotaExhausted: Bool {
        PrivateCloudComputeLanguageModel().quotaUsage.isLimitReached
    }

    /// A reply answered on-device is a fallback worth naming in the UI.
    static let serverModelExists = true

    /// Nearing the daily allowance: keep chat on PCC, let background writes go on-device.
    static var isServerQuotaApproaching: Bool {
        if case .belowLimit(let info) = PrivateCloudComputeLanguageModel().quotaUsage.status {
            return info.isApproachingLimit
        }
        return false
    }

    /// Reasoning is a server-model feature; the on-device model takes the
    /// framework defaults.
    static func respond<Content: Generable>(
        _ session: LanguageModelSession,
        to prompt: String,
        generating type: Content.Type,
        tier: CoachModelTier,
        depth: CoachReasoningDepth
    ) async throws -> Content {
        guard tier == .privateCloud else {
            return try await session.respond(to: prompt, generating: type).content
        }
        return try await session.respond(
            to: prompt,
            generating: type,
            contextOptions: contextOptions(for: depth)
        ).content
    }

    /// Free text, the same way: reasoning on the server model, defaults on-device.
    static func respondText(
        _ session: LanguageModelSession,
        to prompt: String,
        tier: CoachModelTier,
        depth: CoachReasoningDepth
    ) async throws -> String {
        guard tier == .privateCloud else {
            return try await session.respond(to: prompt).content
        }
        return try await session.respond(to: prompt, contextOptions: contextOptions(for: depth)).content
    }

    private static func contextOptions(for depth: CoachReasoningDepth) -> ContextOptions {
        switch depth {
        case .light: return ContextOptions(reasoningLevel: .light)
        case .moderate: return ContextOptions(reasoningLevel: .moderate)
        case .deep: return ContextOptions(reasoningLevel: .deep)
        }
    }

    /// `permissiveGuardrails` relaxes the on-device input classifier for text the
    /// person wrote about themselves — Apple's own knob for user-provided content
    /// that trips the default filter. The model can still decline on its own.
    static func makeSession(
        tier: CoachModelTier,
        instructions: String,
        tools: [any Tool] = [],
        permissiveGuardrails: Bool = false
    ) -> LanguageModelSession {
        switch tier {
        case .privateCloud:
            return LanguageModelSession(
                model: PrivateCloudComputeLanguageModel(),
                tools: tools,
                instructions: instructions
            )
        case .onDevice:
            if permissiveGuardrails {
                return LanguageModelSession(
                    model: SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations),
                    tools: tools,
                    instructions: instructions
                )
            }
            return LanguageModelSession(tools: tools, instructions: instructions)
        }
    }

    /// Where the daily server allowance stands, for Settings and the eval screen.
    static var serverQuotaSummary: String {
        guard serverModelExists else { return "Private Cloud Compute is not available in this build." }
        if isServerQuotaExhausted { return "Private Cloud Compute: today’s limit reached — replies are on-device until it resets." }
        if isServerQuotaApproaching { return "Private Cloud Compute: approaching today’s limit — background writing has moved on-device." }
        if isServerModelAvailable { return "Private Cloud Compute: available." }
        return "Private Cloud Compute: unavailable on this device right now (entitlement, network, or Apple Intelligence)."
    }

    private static func readContextTokens(for tier: CoachModelTier) async -> Int {
        // `contextSize` is an async, throwing read (it fails when the model is
        // not ready); fall back to the assumed window in that case.
        let reported: Int?
        switch tier {
        case .privateCloud: reported = try? await PrivateCloudComputeLanguageModel().contextSize
        case .onDevice: reported = try? await SystemLanguageModel.default.contextSize
        }
        if let reported = reported, reported > 0 { return reported }
        return tier.assumedContextTokens
    }
}
#else
@MainActor
extension CoachModelProvider {
    /// Platforms without the framework (the Linux logic harness): the rest of
    /// the coach still asks these questions and gets "use on-device".
    static var isServerModelAvailable: Bool { false }
    static var isServerQuotaExhausted: Bool { false }
    static var isServerQuotaApproaching: Bool { false }
    static let serverModelExists = false
    static var serverQuotaSummary: String { "Private Cloud Compute is not available in this build." }

    private static func readContextTokens(for tier: CoachModelTier) async -> Int {
        tier.assumedContextTokens
    }
}
#endif
