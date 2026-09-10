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
        cancelReminders(for: goal.id)
        guard goal.remindersEnabled, goal.status == .active, !goal.isComplete, !goal.isExpired else { return }
        guard await isAuthorizedForReminders() else { return }
        guard !Task.isCancelled else { return }

        let center = UNUserNotificationCenter.current()

        var date = DateComponents()
        date.hour = goal.reminderHour
        date.minute = goal.reminderMinute

        for weekday in weekdays(from: goal.reminderWeekdaysMask) {
            guard !Task.isCancelled else { return }
            date.weekday = weekday
            let content = UNMutableNotificationContent()
            content.title = "SMART goal reminder"
            content.body = goal.specificText
            content.sound = .default
            content.categoryIdentifier = NotificationCategoryID.smartGoal
            content.userInfo = ["goalId": goal.id.uuidString]

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
        // Include the legacy unsuffixed ID and all seven repeating requests.
        // A synchronous removal avoids deleting newly scheduled replacements.
        let ids = [prefix] + (1...7).map { "\(prefix)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
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
