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
/// PCC routing is fully wired: intents still prefer the server model, the daily
/// card still asks for it, and a server failure still falls back on-device.
/// The `PrivateCloudComputeLanguageModel` *type* is the only thing gated. It is
/// not in the current Xcode SDK, and `#available(iOS 27)` cannot hide a missing
/// type. Set `DHS_HAS_PRIVATE_CLOUD_COMPUTE` in `project.yml` once the SDK has
/// it and the managed entitlement is on the App ID. That turns the existing
/// routing on; it does not require rewriting the coach.
@MainActor
enum CoachModelProvider {
    private static var cachedContextTokens: [CoachModelTier: Int] = [:]

    /// The tier that should answer this message. Trivial and precomputed
    /// questions stay on-device so the daily allowance is spent where depth
    /// actually changes the answer.
    static func tier(for intent: CoachIntent) -> CoachModelTier {
        guard intent.prefersServerModel, isServerModelAvailable else { return .onDevice }
        return .privateCloud
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
        guard case .available = PrivateCloudComputeLanguageModel().availability else { return false }
        return !isServerQuotaExhausted
    }

    static var isServerQuotaExhausted: Bool {
        guard #available(iOS 27.0, *) else { return false }
        return PrivateCloudComputeLanguageModel().quotaUsage.isLimitReached
    }

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

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    static func makeSession(tier: CoachModelTier, instructions: String) -> LanguageModelSession {
        LanguageModelSession(instructions: instructions)
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
