import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Which model answers a given message.
enum CoachModelTier: String, Equatable, Sendable {
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
/// Every reference to the Private Cloud Compute API lives here so the on-device
/// path stays intact if the server model is unavailable, out of quota, or the
/// app has not been granted the entitlement.
@MainActor
enum CoachModelProvider {
    private static var cachedContextTokens: [CoachModelTier: Int] = [:]

    /// True when the server model can serve this request right now. False keeps
    /// everything on the on-device path, which is the shipping behavior until
    /// the Private Cloud Compute entitlement is granted.
    static var isServerModelAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 27.0, *) {
            if case .available = PrivateCloudComputeLanguageModel().availability {
                return !isServerQuotaExhausted
            }
        }
        #endif
        return false
    }

    /// Daily quota is per person, so a exhausted allowance silently routes back
    /// on-device rather than failing the message.
    static var isServerQuotaExhausted: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 27.0, *) {
            return PrivateCloudComputeLanguageModel().quotaUsage.isLimitReached
        }
        #endif
        return false
    }

    /// The tier that should answer this message. Trivial and precomputed
    /// questions stay on-device so the daily allowance is spent where depth
    /// actually changes the answer.
    static func tier(for intent: CoachIntent) -> CoachModelTier {
        guard intent.prefersServerModel, isServerModelAvailable else { return .onDevice }
        return .privateCloud
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    static func makeSession(tier: CoachModelTier, instructions: String) -> LanguageModelSession {
        if tier == .privateCloud, #available(iOS 27.0, *) {
            return LanguageModelSession(
                model: PrivateCloudComputeLanguageModel(),
                tools: [],
                instructions: instructions
            )
        }
        return LanguageModelSession(instructions: instructions)
    }
    #endif

    /// The tier's real context window, read once from the framework.
    static func contextTokens(for tier: CoachModelTier) async -> Int {
        if let cached = cachedContextTokens[tier] { return cached }
        var resolved = tier.assumedContextTokens
        #if canImport(FoundationModels)
        switch tier {
        case .privateCloud:
            if #available(iOS 27.0, *) {
                if let reported = try? await PrivateCloudComputeLanguageModel().contextSize, reported > 0 {
                    resolved = reported
                }
            }
        case .onDevice:
            if #available(iOS 26.0, *) {
                if let reported = try? await SystemLanguageModel.default.contextSize, reported > 0 {
                    resolved = reported
                }
            }
        }
        #endif
        cachedContextTokens[tier] = resolved
        return resolved
    }

    static func contextBudget(for tier: CoachModelTier) async -> CoachContextBudget {
        CoachContextBudget.make(totalTokens: await contextTokens(for: tier))
    }
}
