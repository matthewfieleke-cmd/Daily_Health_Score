import Foundation
import UserNotifications

/// Schedules today's remaining pace nudges as one-shot local notifications.
///
/// Call `refresh` whenever today's Health snapshot changes. Slots that have
/// already passed are not scheduled (so installing at 4pm does not fire 2:30).
/// Slots that are now on pace are cancelled. Bodies use the numbers at refresh
/// time; a later refresh rewrites anything still in the future.
enum PaceNudgeScheduler {
    static var allIdentifiers: [String] {
        PaceNudgeSlot.allCases.map(\.notificationIdentifier)
    }

    static func cancelAll(center: UNUserNotificationCenter = .current()) {
        center.removePendingNotificationRequests(withIdentifiers: allIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: allIdentifiers)
    }

    static func refresh(
        snapshot: WatchSnapshot,
        enabled: Bool,
        now: Date = Date(),
        calendar: Calendar = .current,
        center: UNUserNotificationCenter = .current()
    ) async {
        guard enabled, snapshot.paceNudgesEnabled, snapshot.isForDay(now, calendar: calendar) else {
            cancelAll(center: center)
            return
        }

        let decisions = PaceNudgeLogic.upcomingDecisions(
            fiberGrams: snapshot.fiber.value,
            fiberGoal: snapshot.fiber.goal,
            exerciseMinutes: snapshot.exercise.value,
            exerciseGoal: snapshot.exercise.goal,
            now: now,
            calendar: calendar
        )
        let keep = Set(decisions.map(\.slot.notificationIdentifier))
        let stale = allIdentifiers.filter { !keep.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
            center.removeDeliveredNotifications(withIdentifiers: stale)
        }

        for decision in decisions {
            guard let fire = decision.slot.fireDate(on: now, calendar: calendar) else { continue }
            let content = UNMutableNotificationContent()
            content.title = decision.title
            content.body = decision.body
            content.sound = .default
            content.categoryIdentifier = NotificationCategoryID.paceNudge
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fire
                ),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: decision.slot.notificationIdentifier,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}

enum NotificationCategoryID {
    static let smartGoal = "SMART_GOAL_REMINDER"
    static let paceNudge = "DHS_PACE_NUDGE"
    static let logCheckInAction = "LOG_CHECK_IN"
}

enum NotificationCategories {
    static func register(center: UNUserNotificationCenter = .current()) {
        let log = UNNotificationAction(
            identifier: NotificationCategoryID.logCheckInAction,
            title: "Log check-in",
            options: []
        )
        let smart = UNNotificationCategory(
            identifier: NotificationCategoryID.smartGoal,
            actions: [log],
            intentIdentifiers: [],
            options: []
        )
        let pace = UNNotificationCategory(
            identifier: NotificationCategoryID.paceNudge,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([smart, pace])
    }
}
