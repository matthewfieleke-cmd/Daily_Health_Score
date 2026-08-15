import SwiftUI
import WatchKit

@main
struct DailyHealthScoreWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate
    @ObservedObject private var snapshot = WatchSnapshotController.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(snapshot)
                .task {
                    snapshot.activate()
                    snapshot.requestNotificationAccessIfNeeded()
                }
        }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        Task { @MainActor in
            WatchSnapshotController.shared.activate()
        }
    }

    func applicationDidBecomeActive() {
        Task { @MainActor in
            WatchSnapshotController.shared.refreshForForeground()
        }
    }
}
