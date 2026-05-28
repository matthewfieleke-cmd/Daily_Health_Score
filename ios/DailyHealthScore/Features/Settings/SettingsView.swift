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
    @State private var showSleepDiagnostic = false
    @State private var exportText = ""
    @State private var selectedSleepGoal: SleepGoalHours = .sevenHalf
    @State private var selectedFiberGoal: FiberGoalGrams = .forty

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
                        Task { await appState.syncTodayFromHealth(userInitiated: true) }
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
                    Button {
                        showSleepDiagnostic = true
                    } label: {
                        Label("Sleep diagnostic", systemImage: "stethoscope")
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
            .onAppear {
                selectedSleepGoal = appState.settingsStore.settings.sleepGoal
                selectedFiberGoal = appState.settingsStore.settings.fiberGoal
            }
            .onChange(of: appState.settingsStore.settings) { _, settings in
                selectedSleepGoal = settings.sleepGoal
                selectedFiberGoal = settings.fiberGoal
            }
            .sheet(isPresented: $showEditDay) {
                EditDayView()
            }
            .sheet(isPresented: $showSleepDiagnostic) {
                SleepDiagnosticView()
                    .environmentObject(appState)
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
            get: { selectedSleepGoal },
            set: { newGoal in
                guard selectedSleepGoal != newGoal else { return }
                selectedSleepGoal = newGoal
                appState.settingsStore.settings.sleepGoal = newGoal
                Task { await appState.refreshTodayAfterGoalChange() }
            }
        )
    }

    private var fiberGoalBinding: Binding<FiberGoalGrams> {
        Binding(
            get: { selectedFiberGoal },
            set: { newGoal in
                guard selectedFiberGoal != newGoal else { return }
                selectedFiberGoal = newGoal
                appState.settingsStore.settings.fiberGoal = newGoal
                Task { await appState.refreshTodayAfterGoalChange() }
            }
        )
    }
}
