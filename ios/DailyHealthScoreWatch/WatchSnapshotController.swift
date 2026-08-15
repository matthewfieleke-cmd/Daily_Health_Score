import Foundation
import SwiftUI
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif
import UserNotifications

/// Watch-side snapshot, check-ins, and wrist nudges.
@MainActor
final class WatchSnapshotController: NSObject, ObservableObject {
    @Published private(set) var snapshot: WatchSnapshot?
    @Published var handshakeNeeded: Bool = true

    private var pendingFills: [UUID: Int] = [:]
    private var pendingOutgoing: [WatchCheckInEvent] = []
    private var didActivate = false

    override init() {
        super.init()
        snapshot = WatchSnapshotStore.load()
        handshakeNeeded = snapshot == nil
    }

    func activate() {
        guard !didActivate else { return }
        didActivate = true
        NotificationCategories.register()
        Task {
            _ = try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        }
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        #endif
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
        let merged = merge(incoming)
        snapshot = merged
        handshakeNeeded = false
        WatchSnapshotStore.save(merged)
        reloadWidgets()
        refreshNudges()
    }

    private func merge(_ incoming: WatchSnapshot) -> WatchSnapshot {
        guard let current = snapshot else { return incoming }
        var result = incoming
        for index in result.goals.indices {
            let id = result.goals[index].id
            guard pendingFills[id, default: 0] > 0,
                  let local = current.goals.first(where: { $0.id == id }) else { continue }
            if result.goals[index].filledCount >= local.filledCount {
                pendingFills[id] = nil
            } else {
                result.goals[index].filledMask = local.filledMask
            }
        }
        return result
    }

    private func sendCheckIn(_ event: WatchCheckInEvent) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        guard WCSession.default.activationState == .activated else {
            pendingOutgoing.append(event)
            return
        }
        guard let json = WatchBridge.encode(event) else { return }
        WCSession.default.transferUserInfo([WatchBridge.userInfoCheckInKey: json])
        #endif
    }

    private func flushOutgoingCheckIns() {
        let queued = pendingOutgoing
        pendingOutgoing = []
        queued.forEach(sendCheckIn)
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

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            guard let json = userInfo[WatchBridge.applicationContextSnapshotKey] as? String,
                  let incoming = WatchBridge.decode(WatchSnapshot.self, from: json) else { return }
            self.applyIncoming(incoming)
        }
    }
}
#endif
