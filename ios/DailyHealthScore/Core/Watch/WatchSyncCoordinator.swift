import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Pushes today's Health-computed snapshot to the Watch and applies Watch check-ins.
///
/// Apple Health stays the source of truth: this type never scores on its own.
/// It publishes after the iPhone has already saved a `DailyRecord`.
@MainActor
final class WatchSyncCoordinator: NSObject, ObservableObject {
    private let recordStore: RecordStore
    private let smartGoalStore: SMARTGoalStore
    private let settingsStore: SettingsStore

    /// Last payload actually sent, so complication transfers only fire when the
    /// face would change.
    private var lastPublished: WatchSnapshot?

    init(recordStore: RecordStore, smartGoalStore: SMARTGoalStore, settingsStore: SettingsStore) {
        self.recordStore = recordStore
        self.smartGoalStore = smartGoalStore
        self.settingsStore = settingsStore
        super.init()
    }

    func activate() {
        NotificationCategories.register()
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        #endif
    }

    func publish() {
        let todayKey = DateHelpers.localDateKey()
        let today = recordStore.records.first { $0.date == todayKey }
        let snapshot = WatchSnapshotBuilder.build(
            today: today,
            goals: smartGoalStore.goals,
            paceNudgesEnabled: settingsStore.paceNudgesEnabled
        )
        WatchSnapshotStore.save(snapshot)
        refreshPaceNudges(with: snapshot)
        sendToWatch(snapshot)
        lastPublished = snapshot
    }

    func applyCheckIn(goalId: UUID) {
        smartGoalStore.fillNextEmpty(on: goalId)
        publish()
    }

    fileprivate func handleIncomingCheckIn(_ userInfo: [String: Any]) {
        guard let json = userInfo[WatchBridge.userInfoCheckInKey] as? String,
              let event = WatchBridge.decode(WatchCheckInEvent.self, from: json) else {
            return
        }
        applyCheckIn(goalId: event.goalId)
    }

    private func refreshPaceNudges(with snapshot: WatchSnapshot) {
        let watchOwnsWrist = isWatchAppInstalled
        Task {
            if watchOwnsWrist {
                PaceNudgeScheduler.cancelAll()
            } else {
                await PaceNudgeScheduler.refresh(
                    snapshot: snapshot,
                    enabled: settingsStore.paceNudgesEnabled
                )
            }
        }
    }

    private var isWatchAppInstalled: Bool {
        #if canImport(WatchConnectivity)
        WCSession.isSupported() && WCSession.default.isPaired && WCSession.default.isWatchAppInstalled
        #else
        false
        #endif
    }

    private func sendToWatch(_ snapshot: WatchSnapshot) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let json = WatchBridge.encode(snapshot) else { return }
        try? session.updateApplicationContext([WatchBridge.applicationContextSnapshotKey: json])

        let faceChanged = lastPublished.map {
            $0.formattedScore != snapshot.formattedScore
                || $0.fiber.value != snapshot.fiber.value
                || $0.exercise.value != snapshot.exercise.value
                || $0.sleep.value != snapshot.sleep.value
                || $0.goals != snapshot.goals
        } ?? true
        if faceChanged, session.isComplicationEnabled {
            session.transferCurrentComplicationUserInfo([WatchBridge.applicationContextSnapshotKey: json])
        }
        #endif
    }
}

#if canImport(WatchConnectivity)
extension WatchSyncCoordinator: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.publish()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in
            self.handleIncomingCheckIn(userInfo)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            if session.isReachable {
                self.publish()
            }
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.publish()
        }
    }
}
#endif
