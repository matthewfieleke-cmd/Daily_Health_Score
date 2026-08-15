import SwiftUI
import SwiftData

@main
struct DailyHealthScoreApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootViewHost()
        }
        .modelContainer(RecordStore.makeContainer())
    }
}
