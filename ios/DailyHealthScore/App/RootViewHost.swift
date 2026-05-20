import SwiftUI
import SwiftData

struct RootViewHost: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState: AppState?

    var body: some View {
        Group {
            if let appState {
                TabView {
                    TodayView()
                        .tabItem { Label("Today", systemImage: "sun.max") }
                    RollingSummaryView(days: 7, title: "7-Day")
                        .tabItem { Label("7-Day", systemImage: "calendar") }
                    RollingSummaryView(days: 30, title: "30-Day")
                        .tabItem { Label("30-Day", systemImage: "calendar.badge.clock") }
                    RollingSummaryView(days: 90, title: "90-Day")
                        .tabItem { Label("90-Day", systemImage: "chart.bar") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
                .environmentObject(appState)
                .tint(Color(red: 0.2, green: 0.45, blue: 0.55))
                .task {
                    await appState.requestHealthAccess()
                    await appState.syncTodayFromHealth()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task { await appState.syncTodayFromHealth() }
                    }
                }
            } else {
                ProgressView("Loading…")
            }
        }
        .onAppear {
            if appState == nil {
                appState = AppState(modelContext: modelContext)
            }
        }
    }
}
