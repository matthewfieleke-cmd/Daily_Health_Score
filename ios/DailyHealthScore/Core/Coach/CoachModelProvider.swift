import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Which model answers a given message.
enum CoachModelTier: String, Equatable, Codable, Sendable {
    /// Apple's server model on Private Cloud Compute: frontier-class breadth,
    /// a 32K context window, and reasoning. Requires iOS 27, a network, the
    /// managed Private Cloud Compute entitlement, and daily quota.
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
        CoachContextBudget.make(totalTokens: await contextTokens(for: tier))
    }

    /// Cached so we do not ask the framework for the window on every message.
    static func contextTokens(for tier: CoachModelTier) async -> Int {
        if let cached = cachedContextTokens[tier] { return cached }
        let resolved = await readContextTokens(for: tier)
        cachedContextTokens[tier] = resolved
        return resolved
    }
}

#if canImport(FoundationModels) && DHS_HAS_PRIVATE_CLOUD_COMPUTE
@MainActor
extension CoachModelProvider {
    static var isServerModelAvailable: Bool {
        guard #available(iOS 27.0, *) else { return false }
        // Account assignment is not enough: the debug profile must include the
        // managed capability. If the type is present but not usable, stay on-device.
        guard case .available = PrivateCloudComputeLanguageModel().availability else { return false }
        return !isServerQuotaExhausted
    }

    static var isServerQuotaExhausted: Bool {
        guard #available(iOS 27.0, *) else { return false }
        return PrivateCloudComputeLanguageModel().quotaUsage.isLimitReached
    }

    /// The app was built against an SDK that has the server model, so a reply
    /// answered on-device is a fallback worth naming in the UI.
    static let serverModelExists = true

    /// Nearing the daily allowance: keep chat on PCC, let background writes go on-device.
    static var isServerQuotaApproaching: Bool {
        guard #available(iOS 27.0, *) else { return false }
        if case .belowLimit(let info) = PrivateCloudComputeLanguageModel().quotaUsage.status {
            return info.isApproachingLimit
        }
        return false
    }

    /// Reasoning rides on the iOS 27 `respond` overload and is a server-model
    /// feature. Under the iOS 26 floor, and for the on-device model, the
    /// framework defaults apply.
    @available(iOS 26.0, *)
    static func respond<Content: Generable>(
        _ session: LanguageModelSession,
        to prompt: String,
        generating type: Content.Type,
        tier: CoachModelTier,
        depth: CoachReasoningDepth
    ) async throws -> Content {
        if tier == .privateCloud, #available(iOS 27.0, *) {
            return try await session.respond(
                to: prompt,
                generating: type,
                contextOptions: contextOptions(for: depth)
            ).content
        }
        return try await session.respond(to: prompt, generating: type).content
    }

    @available(iOS 27.0, *)
    private static func contextOptions(for depth: CoachReasoningDepth) -> ContextOptions {
        switch depth {
        case .light: return ContextOptions(reasoningLevel: .light)
        case .moderate: return ContextOptions(reasoningLevel: .moderate)
        case .deep: return ContextOptions(reasoningLevel: .deep)
        }
    }

    @available(iOS 26.0, *)
    static func makeSession(
        tier: CoachModelTier,
        instructions: String,
        tools: [any Tool] = []
    ) -> LanguageModelSession {
        if tier == .privateCloud, #available(iOS 27.0, *) {
            return LanguageModelSession(
                model: PrivateCloudComputeLanguageModel(),
                tools: tools,
                instructions: instructions
            )
        }
        return LanguageModelSession(tools: tools, instructions: instructions)
    }

    fileprivate static func readContextTokens(for tier: CoachModelTier) async -> Int {
        switch tier {
        case .privateCloud:
            if #available(iOS 27.0, *) {
                if let reported = try? await PrivateCloudComputeLanguageModel().contextSize, reported > 0 {
                    return reported
                }
            }
            return CoachModelTier.privateCloud.assumedContextTokens
        case .onDevice:
            return await onDeviceContextTokens()
        }
    }
}
#else
@MainActor
extension CoachModelProvider {
    /// Always false until the SDK contains `PrivateCloudComputeLanguageModel`
    /// and `DHS_HAS_PRIVATE_CLOUD_COMPUTE` is on. The rest of the coach still
    /// asks this question; it just gets "use on-device" until then.
    static var isServerModelAvailable: Bool { false }
    static var isServerQuotaExhausted: Bool { false }
    static var isServerQuotaApproaching: Bool { false }
    static let serverModelExists = false

    #if canImport(FoundationModels)
    /// No server model in this SDK, so no reasoning level to pass.
    @available(iOS 26.0, *)
    static func respond<Content: Generable>(
        _ session: LanguageModelSession,
        to prompt: String,
        generating type: Content.Type,
        tier: CoachModelTier,
        depth: CoachReasoningDepth
    ) async throws -> Content {
        _ = tier
        _ = depth
        return try await session.respond(to: prompt, generating: type).content
    }

    @available(iOS 26.0, *)
    static func makeSession(
        tier: CoachModelTier,
        instructions: String,
        tools: [any Tool] = []
    ) -> LanguageModelSession {
        return LanguageModelSession(tools: tools, instructions: instructions)
    }
    #endif

    fileprivate static func readContextTokens(for tier: CoachModelTier) async -> Int {
        switch tier {
        case .privateCloud:
            return CoachModelTier.privateCloud.assumedContextTokens
        case .onDevice:
            return await onDeviceContextTokens()
        }
    }
}
#endif

@MainActor
extension CoachModelProvider {
    fileprivate static func onDeviceContextTokens() async -> Int {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if let reported = try? await SystemLanguageModel.default.contextSize, reported > 0 {
                return reported
            }
        }
        #endif
        return CoachModelTier.onDevice.assumedContextTokens
    }
}
