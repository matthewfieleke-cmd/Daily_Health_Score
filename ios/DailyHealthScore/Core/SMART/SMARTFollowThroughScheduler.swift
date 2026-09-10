import Foundation
import UserNotifications

enum SMARTFollowThroughScheduler {
    static let categoryIdentifier = NotificationCategoryID.followThrough

    static func refresh(
        goals: [SMARTGoal],
        activities: [SMARTGoalActivity],
        states: [UUID: CoachFollowThroughState],
        settings: SMARTFollowThroughSettings,
        now: Date = Date(),
        calendar: Calendar = .current,
        center: UNUserNotificationCenter = .current()
    ) async {
        let decisions = SMARTFollowThroughLogic.decisions(
            goals: goals,
            activitiesByGoal: Dictionary(grouping: activities, by: \.goalId),
            states: states,
            settings: settings,
            now: now,
            calendar: calendar
        )
        let keep = Set(decisions.map {
            SMARTFollowThroughLogic.notificationIdentifier(kind: $0.kind, goalId: $0.goalId, dateKey: $0.dateKey)
        })
        let pending = await center.pendingNotificationRequests()
        let stale = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("follow-through-") && !keep.contains($0) }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }
        for decision in decisions {
            let id = SMARTFollowThroughLogic.notificationIdentifier(
                kind: decision.kind,
                goalId: decision.goalId,
                dateKey: decision.dateKey
            )
            let content = UNMutableNotificationContent()
            content.title = decision.title
            content.body = decision.body
            content.sound = .default
            content.categoryIdentifier = NotificationCategoryID.followThrough
            content.userInfo = [
                "goalId": decision.goalId.uuidString,
                "followThroughKind": decision.kind.rawValue
            ]
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: decision.fireDate
                ),
                repeats: false
            )
            try? await center.add(
                UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            )
        }
    }

    static func cancelAll(center: UNUserNotificationCenter = .current()) {
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix("follow-through-") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
