import Foundation

/// Result of a Settings → Refresh Watch face tap. The button used to call
/// `publish` and show nothing, so it looked inactive even when a transfer queued.
enum WatchFacePushOutcome: Equatable {
    case transferred(score: String, remaining: Int, complicationEnabled: Bool)
    case queued(score: String)
    case notPaired
    case appNotInstalled
    case unsupported
    case encodeFailed
    case notActivated

    var isQueued: Bool {
        switch self {
        case .queued, .notActivated: return true
        default: return false
        }
    }

    var isSuccess: Bool {
        switch self {
        case .transferred: return true
        default: return false
        }
    }
}

enum WatchFacePushReport {
    static let sending = "Sending today’s score to your Watch…"
    static let queued = "Watch is connecting. Stay on this screen a moment…"

    static func watchConfirmed(_ score: String) -> String {
        "Watch has \(score). Raise your wrist — the face reads the same feed."
    }

    static func message(_ outcome: WatchFacePushOutcome) -> String {
        switch outcome {
        case let .transferred(score, remaining, enabled):
            if enabled {
                return "Sent \(score). Raise your wrist. Face updates left today: \(max(remaining, 0))."
            }
            return "Sent \(score) to the Watch. Raise your wrist. If a slot still says Open iPhone, wait a few seconds — the face now reads this same send."
        case .queued:
            return queued
        case .notPaired:
            return "No Apple Watch is paired with this iPhone."
        case .appNotInstalled:
            return "The Watch app is not installed yet. Run Daily Health Score to the iPhone from Xcode."
        case .unsupported:
            return "This iPhone cannot talk to Apple Watch."
        case .encodeFailed:
            return "Could not package today’s score. Tap Refresh from Apple Health first."
        case .notActivated:
            return queued
        }
    }
}
