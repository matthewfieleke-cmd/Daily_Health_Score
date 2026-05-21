import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showEditDay = false
    @State private var showClearConfirm = false
    @State private var exportText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Goals") {
                    Picker("Sleep goal (hours)", selection: sleepGoalBinding) {
                        ForEach(SleepGoalHours.allCases) { goal in
                            Text(goal.label).tag(goal)
                        }
                    }
                    Picker("Fiber goal (grams)", selection: fiberGoalBinding) {
                        ForEach(FiberGoalGrams.allCases) { goal in
                            Text("\(goal.rawValue)").tag(goal)
                        }
                    }
                    LabeledContent("Exercise goal", value: "30 minutes (fixed)")
                }

                Section("Apple Health") {
                    Text("Sleep, dietary fiber, and exercise minutes are read from Health when you open the app or tap Refresh on Today.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Request Health access again") {
                        Task { await appState.requestHealthAccess() }
                    }
                }

                Section("Edit data") {
                    Button("Adjust a saved day") { showEditDay = true }
                    Button("Refresh today from Health") {
                        Task { await appState.syncTodayFromHealth() }
                    }
                }

                Section("Data") {
                    Button("Export records as JSON") {
                        exportText = appState.recordStore.exportJSON()
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
                            }
                            .navigationTitle("Export")
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { exportText = "" }
                                }
                            }
                        }
                    }
                    Button("Clear all local data", role: .destructive) {
                        showClearConfirm = true
                    }
                }

                Section("About") {
                    Text("Native iOS app. Data stays on your device. No cloud account required.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .tint(AppTheme.primary)
            .sheet(isPresented: $showEditDay) {
                EditDayView()
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
