import Combine
import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif
import UserNotifications

/// Watch-side snapshot, check-ins, and wrist nudges.
///
/// A singleton so background Watch launches (complication transfer, application
/// context) activate `WCSession` even when the UI `.task` has not run.
@MainActor
final class WatchSnapshotController: NSObject, ObservableObject {
    static let shared = WatchSnapshotController()

    @Published private(set) var snapshot: WatchSnapshot?
    @Published var handshakeNeeded: Bool = true

    private var pendingFills: [UUID: Int] = [:]
    private var pendingOutgoing: [WatchCheckInEvent] = []
    private var didActivate = false

    private override init() {
        super.init()
        snapshot = WatchSnapshotStore.load()
        handshakeNeeded = snapshot == nil
        pendingOutgoing = WatchPendingCheckInStore.load()
        rebuildPendingFills()
    }

    func activate() {
        guard !didActivate else { return }
        didActivate = true
        NotificationCategories.register()
        UNUserNotificationCenter.current().delegate = self
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        #endif
        refreshNudges()
    }

    /// Prompt only when the UI is on screen. A background first launch must not
    /// consume the system prompt and then skip it on the next open.
    func requestNotificationAccessIfNeeded() {
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
    }

    func refreshForForeground() {
        refreshNudges()
    }

    func logCheckIn(goalId: UUID) {
        guard var current = snapshot,
              let index = current.goals.firstIndex(where: { $0.id == goalId }) else {
            return
        }
        guard current.goals[index].fillNextEmpty() else { return }
        pendingFills[goalId, default: 0] += 1
        current.updatedAt = Date()
        snapshot = current
        WatchSnapshotStore.save(current)
        reloadWidgets()
        sendCheckIn(WatchCheckInEvent(goalId: goalId, createdAt: Date()))
    }

    private func applyIncoming(_ incoming: WatchSnapshot) {
        let merged = WatchCheckInMerge.apply(
            current: snapshot,
            incoming: incoming,
            pendingFills: pendingFills
        )
        snapshot = merged.snapshot
        pendingFills = merged.pendingFills
        handshakeNeeded = false
        WatchSnapshotStore.save(merged.snapshot)
        reloadWidgets()
        refreshNudges()
    }

    private func sendCheckIn(_ event: WatchCheckInEvent) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        guard WCSession.default.activationState == .activated else {
            pendingOutgoing.append(event)
            WatchPendingCheckInStore.save(pendingOutgoing)
            return
        }
        guard let json = WatchBridge.encode(event) else { return }
        WCSession.default.transferUserInfo([WatchBridge.userInfoCheckInKey: json])
        #else
        pendingOutgoing.append(event)
        WatchPendingCheckInStore.save(pendingOutgoing)
        #endif
    }

    private func flushOutgoingCheckIns() {
        let queued = pendingOutgoing
        pendingOutgoing = []
        WatchPendingCheckInStore.save([])
        queued.forEach(sendCheckIn)
    }

    private func rebuildPendingFills() {
        pendingFills = [:]
        for event in pendingOutgoing {
            pendingFills[event.goalId, default: 0] += 1
        }
    }

    private func refreshNudges() {
        guard let snapshot else {
            PaceNudgeScheduler.cancelAll()
            return
        }
        Task {
            await PaceNudgeScheduler.refresh(snapshot: snapshot, enabled: snapshot.paceNudgesEnabled)
        }
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}

extension WatchSnapshotController: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard response.actionIdentifier == NotificationCategoryID.logCheckInAction,
              let raw = info["goalId"] as? String,
              let goalId = UUID(uuidString: raw) else { return }
        await MainActor.run {
            self.logCheckIn(goalId: goalId)
        }
    }
}

#if canImport(WatchConnectivity)
extension WatchSnapshotController: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let json = session.receivedApplicationContext[WatchBridge.applicationContextSnapshotKey] as? String,
               let incoming = WatchBridge.decode(WatchSnapshot.self, from: json) {
                self.applyIncoming(incoming)
            }
            self.flushOutgoingCheckIns()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            guard let json = applicationContext[WatchBridge.applicationContextSnapshotKey] as? String,
                  let incoming = WatchBridge.decode(WatchSnapshot.self, from: json) else { return }
            self.applyIncoming(incoming)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            guard let json = userInfo[WatchBridge.applicationContextSnapshotKey] as? String,
                  let incoming = WatchBridge.decode(WatchSnapshot.self, from: json) else { return }
            self.applyIncoming(incoming)
        }
    }
}
#endif
