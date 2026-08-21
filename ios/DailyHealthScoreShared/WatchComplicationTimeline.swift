import Foundation

/// When WidgetKit should ask the complication for a new timeline.
///
/// A single "now" entry that lasts until midnight leaves the face frozen if a
/// complication transfer is skipped. Reloading on a short interval lets the
/// widget re-read the App Group file the Watch app already has.
enum WatchComplicationTimeline {
    static let refreshInterval: TimeInterval = 15 * 60

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
