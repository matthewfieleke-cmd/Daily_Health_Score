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
///
/// `PrivateCloudComputeLanguageModel` is an iOS 27 SDK type. `#available(iOS 27)`
/// is a runtime check and still needs the type at compile time, so those calls
/// are behind `DHS_HAS_PRIVATE_CLOUD_COMPUTE`. Leave that flag off until Xcode's
/// FoundationModels module actually contains the type (a later 27 SDK) and the
/// managed entitlement is on the App ID. Until then every request uses the
/// on-device model, which is the shipping behavior.
@MainActor
enum CoachModelProvider {
    private static var cachedContextTokens: [CoachModelTier: Int] = [:]

    /// True when the server model can serve this request right now. False keeps
    /// everything on the on-device path, which is the shipping behavior until
    /// the Private Cloud Compute entitlement is granted and the SDK has the type.
    static var isServerModelAvailable: Bool {
        #if canImport(FoundationModels) && DHS_HAS_PRIVATE_CLOUD_COMPUTE
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
        #if canImport(FoundationModels) && DHS_HAS_PRIVATE_CLOUD_COMPUTE
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
        #if DHS_HAS_PRIVATE_CLOUD_COMPUTE
        if tier == .privateCloud, #available(iOS 27.0, *) {
            return LanguageModelSession(
                model: PrivateCloudComputeLanguageModel(),
                tools: [],
                instructions: instructions
            )
        }
        #endif
        return LanguageModelSession(instructions: instructions)
    }
    #endif

    /// The tier's real context window, read once from the framework.
    static func contextTokens(for tier: CoachModelTier) async -> Int {
        if let cached = cachedContextTokens[tier] { return cached }
        var resolved = tier.assumedContextTokens
        #if canImport(FoundationModels)
        #if DHS_HAS_PRIVATE_CLOUD_COMPUTE
        if tier == .privateCloud, #available(iOS 27.0, *) {
            if let reported = try? await PrivateCloudComputeLanguageModel().contextSize, reported > 0 {
                resolved = reported
            }
        } else
        #endif
        if tier == .onDevice, #available(iOS 26.0, *) {
            if let reported = try? await SystemLanguageModel.default.contextSize, reported > 0 {
                resolved = reported
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
