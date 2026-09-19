import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Reads the same `WCSession` application context the Watch app already has.
/// The complication is a separate process; if the App Group is dead it can
/// still paint from this feed after a short activate.
enum WatchFaceSessionReader {
    static func fetch(timeout: TimeInterval = 1.5, completion: @escaping (WatchSnapshot?) -> Void) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else {
            completion(nil)
            return
        }
        Holder.start(timeout: timeout, completion: completion)
        #else
        completion(nil)
        #endif
    }

    #if canImport(WatchConnectivity)
    private final class Holder: NSObject, WCSessionDelegate {
        static var inFlight: Holder?

        private var completion: ((WatchSnapshot?) -> Void)?
        private var finished = false

        static func start(timeout: TimeInterval, completion: @escaping (WatchSnapshot?) -> Void) {
            let holder = Holder()
            holder.completion = completion
            inFlight = holder
            let session = WCSession.default
            session.delegate = holder
            if session.activationState == .activated {
                holder.finish(WatchBridge.snapshot(from: session.receivedApplicationContext))
                return
            }
            session.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak holder] in
                holder?.finish(WatchBridge.snapshot(from: WCSession.default.receivedApplicationContext))
            }
        }

        func session(
            _ session: WCSession,
            activationDidCompleteWith activationState: WCSessionActivationState,
            error: Error?
        ) {
            finish(WatchBridge.snapshot(from: session.receivedApplicationContext))
        }

        private func finish(_ snapshot: WatchSnapshot?) {
            guard !finished else { return }
            finished = true
            if let snapshot {
                WatchSnapshotStore.save(snapshot)
            }
            completion?(snapshot)
            completion = nil
            if Holder.inFlight === self {
                Holder.inFlight = nil
            }
        }
    }
    #endif
}
