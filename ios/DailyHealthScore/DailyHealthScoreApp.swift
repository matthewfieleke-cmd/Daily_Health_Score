import SwiftUI
import SwiftData

@main
struct DailyHealthScoreApp: App {
    var body: some Scene {
        WindowGroup {
            RootViewHost()
        }
        .modelContainer(RecordStore.makeContainer())
    }
}
