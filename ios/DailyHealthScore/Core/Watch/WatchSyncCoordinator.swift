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
    /// Last `isComplicationEnabled` we observed, so adding the face later still pushes.
    private var lastComplicationEnabled: Bool?
    /// Newest workout end we already spent a face update on.
    private(set) var lastPushedWorkoutEndDate: Date = .distantPast
    /// Last time we called `transferCurrentComplicationUserInfo`.
    private var lastComplicationTransferAt: Date?
    /// Held while `WCSession` is still activating so a Health wake is not dropped.
    private var pendingSend: WatchPendingSend?
    /// Settings shows this after Refresh Watch face so the button is never a no-op.
    @Published private(set) var facePushMessage: String = ""
    @Published private(set) var facePushSucceeded: Bool = false
    @Published private(set) var isRefreshingFace: Bool = false
    /// A Refresh tap queued because `WCSession` was still activating.
    private var refreshAwaitingFlush = false

    init(recordStore: RecordStore, smartGoalStore: SMARTGoalStore, settingsStore: SettingsStore) {
        self.recordStore = recordStore
        self.smartGoalStore = smartGoalStore
        self.settingsStore = settingsStore
        super.init()
        lastComplicationFace = LastComplicationFaceStore.load()
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
        latestWorkoutEnd: Date? = nil,
        forceComplication: Bool = false
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
        let outcome = sendToWatch(
            snapshot,
            kind: kind,
            endedWorkoutSinceLastPush: endedWorkoutSinceLastPush,
            latestWorkoutEnd: latestWorkoutEnd,
            forceComplication: forceComplication
        )
        if case .transferred = outcome, endedWorkoutSinceLastPush, let latestWorkoutEnd {
            lastPushedWorkoutEndDate = latestWorkoutEnd
        }
        if refreshAwaitingFlush || forceComplication {
            presentFacePush(outcome)
        }
    }

    /// Settings → Refresh Watch face. Always leaves a visible status so the
    /// control cannot look dead, and always force-activates the session first.
    func refreshWatchFace() {
        activate()
        isRefreshingFace = true
        facePushSucceeded = false
        facePushMessage = WatchFacePushReport.sending
        refreshAwaitingFlush = true
        publish(kind: .foreground, forceComplication: true)
    }

    private func presentFacePush(_ outcome: WatchFacePushOutcome) {
        if outcome.isQueued {
            refreshAwaitingFlush = true
            isRefreshingFace = true
            facePushSucceeded = false
            facePushMessage = WatchFacePushReport.message(outcome)
            if !WatchSnapshotStore.canShareGroup {
                facePushMessage += " Enable the App Group on the iPhone target in Xcode."
            }
            return
        }
        refreshAwaitingFlush = false
        isRefreshingFace = false
        facePushSucceeded = outcome.isSuccess
        var text = WatchFacePushReport.message(outcome)
        if !WatchSnapshotStore.canShareGroup {
            text += " Enable the App Group on iPhone, Watch, and the widget."
        }
        facePushMessage = text
    }

    func applyCheckIn(goalId: UUID) {
        smartGoalStore.fillNextEmpty(on: goalId)
        publish(kind: .foreground)
    }

    fileprivate func handleIncomingUserInfo(_ userInfo: [String: Any]) {
        if userInfo[WatchBridge.userInfoRefreshFaceKey] != nil {
            publish(kind: .foreground, forceComplication: true)
            return
        }
        guard let json = userInfo[WatchBridge.userInfoCheckInKey] as? String,
              let event = WatchBridge.decode(WatchCheckInEvent.self, from: json) else {
            return
        }
        _ = smartGoalStore.applyWatchEvent(event)
        publish(kind: .foreground)
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
        queueIfUnready: Bool = true,
        forceComplication: Bool = false
    ) -> WatchFacePushOutcome {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return .unsupported }
        let session = WCSession.default
        if session.activationState == .activated, !session.isPaired {
            return .notPaired
        }
        if session.activationState == .activated, session.isPaired, !session.isWatchAppInstalled {
            return .appNotInstalled
        }
        guard session.activationState == .activated else {
            if queueIfUnready {
                pendingSend = WatchPendingSendMerge.replacing(
                    pendingSend,
                    with: WatchPendingSend(
                        snapshot: snapshot,
                        kind: kind,
                        endedWorkoutSinceLastPush: endedWorkoutSinceLastPush,
                        latestWorkoutEnd: latestWorkoutEnd,
                        forceComplication: forceComplication
                    )
                )
            }
            return .queued(score: snapshot.formattedScore)
        }
        guard let json = WatchBridge.encode(snapshot) else { return .encodeFailed }
        try? session.updateApplicationContext([WatchBridge.applicationContextSnapshotKey: json])
        // Application context plus a userInfo copy: the Watch app can persist
        // and reload even when the complication transfer is degraded.
        if forceComplication || kind == .foreground {
            session.transferUserInfo([WatchBridge.applicationContextSnapshotKey: json])
        }
        if session.isReachable {
            session.sendMessage(
                [WatchBridge.applicationContextSnapshotKey: json],
                replyHandler: { [weak self] reply in
                    Task { @MainActor in
                        if let score = reply[WatchBridge.userInfoConfirmedScoreKey] as? String {
                            self?.facePushMessage = WatchFacePushReport.watchConfirmed(score)
                            self?.facePushSucceeded = true
                            self?.isRefreshingFace = false
                            self?.refreshAwaitingFlush = false
                        }
                    }
                },
                errorHandler: { _ in }
            )
        }

        let nextFace = ComplicationPushPolicy.Face(snapshot)
        let watchPath = session.watchDirectoryURL?.path
        let watchReplaced = PairedWatchIdentityStore.hasChanged(currentPath: watchPath)
        let complicationEnabled = session.isComplicationEnabled
        let justEnabled = ComplicationEnabledEdge.justBecameEnabled(
            previous: lastComplicationEnabled,
            current: complicationEnabled
        )
        lastComplicationEnabled = complicationEnabled
        // Do not coerce remaining to 0 when `isComplicationEnabled` is false.
        // That flag is a false-negative on Modular Ultra / watchOS 27; zeroing
        // it here is why the Ultra 4 face stayed on "Open iPhone".
        let remaining = session.remainingComplicationUserInfoTransfers
        let previousFace = watchReplaced ? nil : lastComplicationFace
        let alreadyOnThisWatch = !watchReplaced && lastComplicationFace == nextFace
        let shouldPush = ComplicationTransferDecision.shouldTransfer(
            ComplicationTransferDecision.Input(
                remainingTransfers: remaining,
                complicationEnabled: complicationEnabled,
                justEnabled: justEnabled,
                watchReplaced: watchReplaced,
                alreadyOnThisWatch: alreadyOnThisWatch,
                forceComplication: forceComplication,
                kind: kind,
                endedWorkoutSinceLastPush: endedWorkoutSinceLastPush,
                previousFace: previousFace,
                nextFace: nextFace
            )
        )
        let faceIsStale = lastComplicationTransferAt.map { Date().timeIntervalSince($0) > 300 } ?? true
        let pushNow = shouldPush || (kind == .foreground && faceIsStale)
        if pushNow {
            session.transferCurrentComplicationUserInfo([WatchBridge.applicationContextSnapshotKey: json])
            lastComplicationTransferAt = Date()
            lastComplicationFace = nextFace
            LastComplicationFaceStore.save(nextFace)
            PairedWatchIdentityStore.remember(currentPath: watchPath)
        }
        return .transferred(
            score: snapshot.formattedScore,
            remaining: remaining,
            complicationEnabled: complicationEnabled
        )
        #else
        return .unsupported
        #endif
    }

    /// Sends the newest queued snapshot. Does not rebuild from disk, so a
    /// Health wake that finished before activation is not replaced by an
    /// empty launch publish.
    private func flushPendingSend() {
        guard let pending = pendingSend else { return }
        pendingSend = nil
        let outcome = sendToWatch(
            pending.snapshot,
            kind: pending.kind,
            endedWorkoutSinceLastPush: pending.endedWorkoutSinceLastPush,
            latestWorkoutEnd: pending.latestWorkoutEnd,
            queueIfUnready: false,
            forceComplication: pending.forceComplication
        )
        if case .transferred = outcome, pending.endedWorkoutSinceLastPush, let end = pending.latestWorkoutEnd {
            lastPushedWorkoutEndDate = end
        }
        if refreshAwaitingFlush || pending.forceComplication {
            presentFacePush(outcome)
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
            self.handleIncomingUserInfo(userInfo)
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
