import SwiftUI

/// Settings is a native iOS Form. The Apple Watch section may make the screen
/// scroll on smaller phones; that is preferred to hiding the pace-nudge toggle.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showEditDay = false
    @State private var showClearConfirm = false
    @State private var showClearCoachConfirm = false
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
                        Label("Refresh from Apple Health", systemImage: "arrow.clockwise")
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

                Section("Apple Watch") {
                    Toggle("Afternoon & evening reminders", isOn: paceNudgeBinding)
                    Text("If fiber or movement is still low later in the day, your Watch (or iPhone, if no Watch is paired) will remind you. Fiber reminders ask you to log a meal on iPhone or eat a high-fiber food — they never log from the Watch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Add the Daily Health Score complication from the Watch face editor after installing the Watch app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("DHS Lifestyle Coach") {
                    Button(role: .destructive) {
                        showClearCoachConfirm = true
                    } label: {
                        Label("Clear coach chat & memory", systemImage: "bubble.left.and.bubble.right")
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
            .enlargedAppNavigationBar(title: "Settings")
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
                    appState.coach.clearMemory()
                }
            } message: {
                Text("This removes all saved daily records and coach memory on this device. It cannot be undone.")
            }
            .alert("Clear coach memory?", isPresented: $showClearCoachConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    appState.coach.clearMemory()
                }
            } message: {
                Text("This clears your coach conversations and what the coach has learned about your preferences. Health scores and SMART goals are not affected.")
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

    private var paceNudgeBinding: Binding<Bool> {
        Binding(
            get: { appState.settingsStore.paceNudgesEnabled },
            set: { enabled in
                appState.settingsStore.paceNudgesEnabled = enabled
                if enabled {
                    Task {
                        _ = await SMARTNotificationService.requestAuthorization()
                        appState.watchSync.publish()
                    }
                } else {
                    PaceNudgeScheduler.cancelAll()
                    appState.watchSync.publish()
                }
            }
        )
    }
}
