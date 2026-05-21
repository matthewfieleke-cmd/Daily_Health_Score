import SwiftUI

/// Settings is a single-screen native iOS Form. Sections are trimmed so the
/// whole screen fits inside the safe area on the standard iPhone 15 without
/// scrolling. We use inline title display, drop the "About" / explanatory
/// blurbs, and merge "Apple Health" + "Edit data" into one Apple Health
/// section.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showEditDay = false
    @State private var showClearConfirm = false
    @State private var exportText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Goals") {
                    Picker("Sleep goal", selection: sleepGoalBinding) {
                        ForEach(SleepGoalHours.allCases) { goal in
                            Text("\(goal.label) hr").tag(goal)
                        }
                    }
                    Picker("Fiber goal", selection: fiberGoalBinding) {
                        ForEach(FiberGoalGrams.allCases) { goal in
                            Text("\(goal.rawValue) g").tag(goal)
                        }
                    }
                    LabeledContent("Exercise goal", value: "30 min")
                }

                Section("Apple Health") {
                    Button {
                        Task { await appState.syncTodayFromHealth() }
                    } label: {
                        Label("Refresh today from Health", systemImage: "arrow.clockwise")
                    }
                    Button {
                        showEditDay = true
                    } label: {
                        Label("Adjust a saved day", systemImage: "pencil")
                    }
                    Button {
                        Task { await appState.requestHealthAccess() }
                    } label: {
                        Label("Request Health access again", systemImage: "heart.text.square")
                    }
                }

                Section("Data") {
                    Button {
                        exportText = appState.recordStore.exportJSON()
                    } label: {
                        Label("Export records as JSON", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear all local data", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .tint(AppTheme.primary)
            .sheet(isPresented: $showEditDay) {
                EditDayView()
            }
            .sheet(isPresented: Binding(
                get: { !exportText.isEmpty },
                set: { if !$0 { exportText = "" } }
            )) {
                NavigationStack {
                    ScrollView {
                        Text(exportText)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .navigationTitle("Export")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { exportText = "" }
                        }
                    }
                }
            }
            .alert("Clear all data?", isPresented: $showClearConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Erase", role: .destructive) {
                    appState.recordStore.deleteAll()
                    appState.settingsStore.clearRotationState()
                }
            } message: {
                Text("This removes all saved daily records on this device. It cannot be undone.")
            }
        }
    }

    private var sleepGoalBinding: Binding<SleepGoalHours> {
        Binding(
            get: { appState.settingsStore.settings.sleepGoal },
            set: { appState.settingsStore.settings.sleepGoal = $0 }
        )
    }

    private var fiberGoalBinding: Binding<FiberGoalGrams> {
        Binding(
            get: { appState.settingsStore.settings.fiberGoal },
            set: { appState.settingsStore.settings.fiberGoal = $0 }
        )
    }
}
