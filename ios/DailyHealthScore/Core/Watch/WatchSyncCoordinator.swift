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

    /// Last face that actually received a complication transfer.
    private var lastComplicationFace: ComplicationPushPolicy.Face?
    /// Newest workout end we already spent a face update on.
    private(set) var lastPushedWorkoutEndDate: Date = .distantPast
    /// Held while `WCSession` is still activating so a Health wake is not dropped.
    private var pendingSend: WatchPendingSend?

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

    func publish(
        kind: HealthChangeKind = .foreground,
        endedWorkoutSinceLastPush: Bool = false,
        latestWorkoutEnd: Date? = nil
    ) {
        let todayKey = DateHelpers.localDateKey()
        let today = recordStore.records.first { $0.date == todayKey }
        let snapshot = WatchSnapshotBuilder.build(
            today: today,
            goals: smartGoalStore.goals,
            paceNudgesEnabled: settingsStore.paceNudgesEnabled
        )
        WatchSnapshotStore.save(snapshot)
        refreshPaceNudges(with: snapshot)
        let transferred = sendToWatch(
            snapshot,
            kind: kind,
            endedWorkoutSinceLastPush: endedWorkoutSinceLastPush,
            latestWorkoutEnd: latestWorkoutEnd
        )
        if transferred, endedWorkoutSinceLastPush, let latestWorkoutEnd {
            lastPushedWorkoutEndDate = latestWorkoutEnd
        }
    }

    func applyCheckIn(goalId: UUID) {
        smartGoalStore.fillNextEmpty(on: goalId)
        publish(kind: .foreground)
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

    @discardableResult
    private func sendToWatch(
        _ snapshot: WatchSnapshot,
        kind: HealthChangeKind,
        endedWorkoutSinceLastPush: Bool,
        latestWorkoutEnd: Date?,
        queueIfUnready: Bool = true
    ) -> Bool {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return false }
        let session = WCSession.default
        guard session.activationState == .activated else {
            if queueIfUnready {
                pendingSend = WatchPendingSendMerge.replacing(
                    pendingSend,
                    with: WatchPendingSend(
                        snapshot: snapshot,
                        kind: kind,
                        endedWorkoutSinceLastPush: endedWorkoutSinceLastPush,
                        latestWorkoutEnd: latestWorkoutEnd
                    )
                )
            }
            return false
        }
        guard let json = WatchBridge.encode(snapshot) else { return false }
        try? session.updateApplicationContext([WatchBridge.applicationContextSnapshotKey: json])

        let nextFace = ComplicationPushPolicy.Face(snapshot)
        let remaining = session.isComplicationEnabled
            ? session.remainingComplicationUserInfoTransfers
            : 0
        let shouldPush = ComplicationPushPolicy.shouldPushComplication(
            from: lastComplicationFace,
            to: nextFace,
            kind: kind,
            endedWorkoutSinceLastPush: endedWorkoutSinceLastPush,
            remainingTransfers: remaining
        )
        guard shouldPush, session.isComplicationEnabled else { return false }
        session.transferCurrentComplicationUserInfo([WatchBridge.applicationContextSnapshotKey: json])
        lastComplicationFace = nextFace
        return true
        #else
        return false
        #endif
    }

    /// Sends the newest queued snapshot. Does not rebuild from disk, so a
    /// Health wake that finished before activation is not replaced by an
    /// empty launch publish.
    private func flushPendingSend() {
        guard let pending = pendingSend else { return }
        pendingSend = nil
        let transferred = sendToWatch(
            pending.snapshot,
            kind: pending.kind,
            endedWorkoutSinceLastPush: pending.endedWorkoutSinceLastPush,
            latestWorkoutEnd: pending.latestWorkoutEnd,
            queueIfUnready: false
        )
        if transferred, pending.endedWorkoutSinceLastPush, let end = pending.latestWorkoutEnd {
            lastPushedWorkoutEndDate = end
        }
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
            guard activationState == .activated else { return }
            self.flushPendingSend()
            self.publish(kind: .foreground)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            self.handleIncomingCheckIn(userInfo)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            if session.isReachable {
                self.publish(kind: .foreground)
            }
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.publish(kind: .foreground)
        }
    }
}
#endif
