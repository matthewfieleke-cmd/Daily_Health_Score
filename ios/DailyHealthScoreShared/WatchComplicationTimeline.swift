import Foundation

/// When WidgetKit should ask the complication for a new timeline.
///
/// A single "now" entry that lasts until midnight leaves the face frozen if a
/// complication transfer is skipped. Reloading on a short interval lets the
/// widget re-read the App Group file the Watch app already has.
enum WatchComplicationTimeline {
    static let refreshInterval: TimeInterval = 5 * 60

    /// Next time to rebuild the timeline. Midnight still wins when it is closer
    /// than the refresh, so yesterday never sits on the face after 12:00.
    static func reloadDate(now: Date, midnight: Date?) -> Date {
        let periodic = now.addingTimeInterval(refreshInterval)
        guard let midnight else { return periodic }
        if midnight.timeIntervalSince(now) <= refreshInterval {
            return midnight.addingTimeInterval(60)
        }
        return periodic
    }
}

/// Watch-side throttle for `refreshFace` userInfo. Asking once per day left the
/// Ultra 4 stuck when the first request was dropped or the iPhone skipped the transfer.
enum WatchFaceRefreshCooldown {
    static let minimumInterval: TimeInterval = 90

    static func shouldRequest(lastRequestedAt: Date?, now: Date = Date()) -> Bool {
        guard let lastRequestedAt else { return true }
        return now.timeIntervalSince(lastRequestedAt) >= minimumInterval
    }
}
