import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Settings is a native iOS Form. The Apple Watch section may make the screen
/// scroll on smaller phones; that is preferred to hiding the pace-nudge toggle.
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showEditDay = false
    @State private var showClearConfirm = false
    @State private var showClearCoachConfirm = false
    @State private var showDeleteChatsConfirm = false
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
                    WatchFaceRefreshButton(watchSync: appState.watchSync)
                    if !appState.watchSync.facePushMessage.isEmpty {
                        WatchFaceRefreshStatus(watchSync: appState.watchSync)
                    }
                    Text("Add the Daily Health Score complication from the Watch face editor. Refresh Watch face stays enabled and reports what happened. If a slot still says Open iPhone after a successful send, raise your wrist and wait a few seconds.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("DHS Lifestyle Coach") {
                    Button {
                        appState.showCoachMemory = true
                    } label: {
                        Label("What your coach remembers", systemImage: "brain.head.profile")
                    }
                    Button(role: .destructive) {
                        showDeleteChatsConfirm = true
                    } label: {
                        Label("Delete all chats", systemImage: "bubble.left.and.bubble.right")
                    }
                    Button(role: .destructive) {
                        showClearCoachConfirm = true
                    } label: {
                        Label("Clear chats and memory", systemImage: "trash")
                    }
                    Text("Deleting chats keeps what your coach has learned about you. Clearing memory removes the notes too.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CoachModelProvider.serverQuotaSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        CoachEvalView()
                            .environmentObject(appState)
                            .environmentObject(appState.coach)
                    } label: {
                        Label("Coach eval (developer)", systemImage: "checklist")
                    }
                    Text(CoachSecrets.hasUSDAKey
                         ? "Food lookups use USDA FoodData Central with the app’s key, then Open Food Facts. Studies come from PubMed. These requests carry a food or topic name only, never your data."
                         : "Food lookups use USDA FoodData Central on a shared demo key (limited) and Open Food Facts. Studies come from PubMed. These requests carry a food or topic name only, never your data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Food data © USDA FoodData Central (public domain) and Open Food Facts contributors (ODbL).")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Section("Follow-through quiet hours") {
                    Toggle("Quiet hours", isOn: quietHoursBinding)
                    if appState.settingsStore.followThroughSettings.quietHoursEnabled {
                        DatePicker("Start", selection: quietStart, displayedComponents: .hourAndMinute)
                        DatePicker("End", selection: quietEnd, displayedComponents: .hourAndMinute)
                    }
                    Text("Opt-in SMART goal reminders skip these hours. They refresh when the app opens and do not generate coaching in the background.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            .alert("Delete all chats?", isPresented: $showDeleteChatsConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    appState.coach.deleteAllChats()
                }
            } message: {
                Text("Every conversation with your coach is removed from this device. What your coach remembers about you stays. Health scores and SMART goals are not affected.")
            }
            .alert("Clear chats and memory?", isPresented: $showClearCoachConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    appState.coach.clearMemory()
                }
            } message: {
                Text("This clears your coach conversations and every note your coach keeps about you. Health scores and SMART goals are not affected.")
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
                        appState.watchSync.publish(forceComplication: true)
                    }
                } else {
                    PaceNudgeScheduler.cancelAll()
                    appState.watchSync.publish(forceComplication: true)
                }
            }
        )
    }

    private var quietHoursBinding: Binding<Bool> {
        Binding(
            get: { appState.settingsStore.followThroughSettings.quietHoursEnabled },
            set: { enabled in
                var settings = appState.settingsStore.followThroughSettings
                settings.quietHoursEnabled = enabled
                appState.settingsStore.followThroughSettings = settings
                Task { await appState.refreshFollowThrough() }
            }
        )
    }

    private var quietStart: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: appState.settingsStore.followThroughSettings.quietHoursStartHour,
                    minute: 0,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: {
                var settings = appState.settingsStore.followThroughSettings
                settings.quietHoursStartHour = Calendar.current.component(.hour, from: $0)
                appState.settingsStore.followThroughSettings = settings
                Task { await appState.refreshFollowThrough() }
            }
        )
    }

    private var quietEnd: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: appState.settingsStore.followThroughSettings.quietHoursEndHour,
                    minute: 0,
                    second: 0,
                    of: Date()
                ) ?? Date()
            },
            set: {
                var settings = appState.settingsStore.followThroughSettings
                settings.quietHoursEndHour = Calendar.current.component(.hour, from: $0)
                appState.settingsStore.followThroughSettings = settings
                Task { await appState.refreshFollowThrough() }
            }
        )
    }
}

/// Observes `WatchSyncCoordinator` directly. `AppState.watchSync` is not
/// `@Published`, so a nested status string would not redraw this Form without
/// this object — that is why Refresh looked inactive.
private struct WatchFaceRefreshButton: View {
    @ObservedObject var watchSync: WatchSyncCoordinator

    var body: some View {
        Button {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            watchSync.refreshWatchFace()
        } label: {
            // A Label keeps a leading icon column in this Form and shifts the title.
            Text(watchSync.isRefreshingFace ? "Sending to Watch…" : "Refresh Watch face")
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(false)
    }
}

private struct WatchFaceRefreshStatus: View {
    @ObservedObject var watchSync: WatchSyncCoordinator

    var body: some View {
        Text(watchSync.facePushMessage)
            .font(.caption)
            .foregroundStyle(watchSync.facePushSucceeded ? Color.green : Color.secondary)
    }
}
