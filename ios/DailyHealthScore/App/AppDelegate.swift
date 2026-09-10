import Foundation
import UIKit
import UserNotifications

/// AppState registers a handler here so the notification delegate can fill a
/// SMART goal without holding a view.
@MainActor
enum NotificationActionRouter {
    static var handleSMARTCheckIn: ((UUID) -> Void)?
    static var handleFollowThroughSnooze: ((UUID) -> Void)?
    static var handleFollowThroughDismiss: ((UUID) -> Void)?
    static var handleNotificationOpen: ((UUID, String) -> Void)?
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationCategories.register()
        Task {
            await HealthKitService.shared.startBackgroundDelivery()
        }
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let kind = info["followThroughKind"] as? String ?? ""
        guard let raw = info["goalId"] as? String,
              let goalId = UUID(uuidString: raw) else {
            return
        }
        await MainActor.run {
            switch response.actionIdentifier {
            case NotificationCategoryID.logCheckInAction:
                NotificationActionRouter.handleSMARTCheckIn?(goalId)
            case NotificationCategoryID.snoozeAction:
                NotificationActionRouter.handleFollowThroughSnooze?(goalId)
            case NotificationCategoryID.dismissAction:
                NotificationActionRouter.handleFollowThroughDismiss?(goalId)
            case UNNotificationDefaultActionIdentifier:
                NotificationActionRouter.handleNotificationOpen?(goalId, kind)
            default:
                break
            }
        }
    }
}
