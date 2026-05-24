import SwiftUI
import SwiftData

struct RootViewHost: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        AppRootContent(modelContext: modelContext)
    }
}

/// Holds a stable `AppState` so launch never flashes a loading screen.
private struct AppRootContent: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState: AppState
    @State private var didFinishLaunchSync = false

    init(modelContext: ModelContext) {
        _appState = StateObject(wrappedValue: AppState(modelContext: modelContext))
    }

    var body: some View {
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
        .tint(AppTheme.primary)
        .task {
            await appState.requestHealthAccess()
            await appState.syncTodayFromHealth()
            didFinishLaunchSync = true
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Only sync when returning from background — not on the initial
            // `.active` at launch (`.task` already handles that).
            guard didFinishLaunchSync, newPhase == .active, oldPhase != .active else { return }
            Task { await appState.syncTodayFromHealth() }
        }
    }
}
