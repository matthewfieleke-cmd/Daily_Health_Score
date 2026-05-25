import Foundation
import UserNotifications

enum SMARTNotificationService {
    static let categoryIdentifier = "SMART_GOAL_REMINDER"

    static func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func isAuthorizedForReminders() async -> Bool {
        let status = await authorizationStatus()
        return status == .authorized || status == .provisional
    }

    static func scheduleReminder(for goal: SMARTGoal) async {
        guard goal.remindersEnabled, goal.status == .active, !goal.isComplete else { return }
        guard await isAuthorizedForReminders() else { return }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationId(goal.id)])

        var date = DateComponents()
        date.hour = goal.reminderHour
        date.minute = goal.reminderMinute

        for weekday in weekdays(from: goal.reminderWeekdaysMask) {
            date.weekday = weekday
            let content = UNMutableNotificationContent()
            content.title = "SMART goal reminder"
            content.body = goal.specificText
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            let request = UNNotificationRequest(
                identifier: "\(notificationId(goal.id))-\(weekday)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    static func cancelReminders(for goalId: UUID) {
        let prefix = notificationId(goalId)
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(prefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    private static func notificationId(_ id: UUID) -> String {
        "smart-goal-\(id.uuidString)"
    }

    /// Calendar weekday 1 = Sunday … 7 = Saturday (Foundation convention).
    private static func weekdays(from mask: Int) -> [Int] {
        if mask == 0 {
            return Array(1 ... 7)
        }
        return (1 ... 7).filter { (mask & (1 << ($0 - 1))) != 0 }
    }

    /// All days of week selected.
    static let allWeekdaysMask: Int = (1 << 7) - 1
}
