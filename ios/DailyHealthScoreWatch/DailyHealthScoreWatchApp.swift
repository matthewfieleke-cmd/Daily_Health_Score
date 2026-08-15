import SwiftUI

@main
struct DailyHealthScoreWatchApp: App {
    @StateObject private var snapshot = WatchSnapshotController()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(snapshot)
                .task { snapshot.activate() }
        }
    }
}
