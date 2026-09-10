import SwiftUI

struct SMARTGoalEditorView: View {
    @EnvironmentObject private var appState: AppState
    let edit: SMARTGoalEdit
    var onSave: ((SMARTGoal) -> Void)?

    var body: some View {
        SMARTGoalEditorContent(store: appState.smartGoalStore, edit: edit, onSave: onSave)
    }
}

private struct SMARTGoalEditorContent: View {
    @ObservedObject var store: SMARTGoalStore
    @Environment(\.dismiss) private var dismiss
    @State private var edit: SMARTGoalEdit
    @State private var isSaving = false
    @State private var saveError: String?
    var onSave: ((SMARTGoal) -> Void)?

    init(store: SMARTGoalStore, edit: SMARTGoalEdit, onSave: ((SMARTGoal) -> Void)?) {
        self.store = store
        _edit = State(initialValue: edit)
        self.onSave = onSave
    }

    private var latest: SMARTGoal? { store.goals.first { $0.id == edit.id } }
    private var validation: String? { edit.validationMessage(latest: latest) }

    var body: some View {
        Form {
            Section("Specific action") {
                TextField("What will you do?", text: $edit.specificText, axis: .vertical)
                    .lineLimit(2...6)
                Text("Describe what one check-in means, including a duration or cue if useful.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Measurable target") {
                Stepper("\(edit.targetCount) check-ins", value: $edit.targetCount, in: 1...30)
                if let latest {
                    Text("\(latest.filledCount) already recorded. Saving keeps your existing check-ins.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Relevant to you") {
                Picker("Area of life", selection: $edit.relevantTheme) {
                    ForEach(SMARTRelevantTheme.allCases) { theme in
                        Text(theme.label).tag(theme)
                    }
                }
            }
            Section("Deadline") {
                DatePicker("Complete by", selection: $edit.endDate, displayedComponents: [.date, .hourAndMinute])
                Text("Choose an achievable timeframe within the next 30 days. Extending an ended goal reopens it with its progress intact.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Reminders") {
                Toggle("Remind me", isOn: $edit.remindersEnabled)
                if edit.remindersEnabled {
                    DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
                    reminderDays
                }
            }
            Section("Review your goal") {
                Text(edit.summary)
                Text("Does this feel realistic? You can adjust the action, target, or deadline before saving.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let message = saveError ?? validation {
                Section {
                    Text(message).foregroundStyle(.red)
                }
            }
        }
        .disabled(isSaving)
        .navigationTitle(edit.original == nil ? "Review SMART Goal" : "Edit SMART Goal")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(isSaving)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }.disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving…" : "Save") { save() }
                    .disabled(isSaving || validation != nil)
            }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: edit.reminderHour, minute: edit.reminderMinute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                edit.reminderHour = parts.hour ?? 9
                edit.reminderMinute = parts.minute ?? 0
            }
        )
    }

    private var reminderDays: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { day in
                let selected = edit.reminderWeekdaysMask & (1 << (day - 1)) != 0
                Button {
                    edit.reminderWeekdaysMask ^= 1 << (day - 1)
                } label: {
                    Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selected ? AppTheme.primary.opacity(0.15) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityValue(selected ? "Selected" : "Not selected")
            }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        saveError = nil
        let reviewed = edit
        Task { @MainActor in
            defer { isSaving = false }
            if reviewed.remindersEnabled {
                let permitted = await SMARTNotificationService.requestAuthorization()
                if !permitted {
                    edit.remindersEnabled = false
                    saveError = "Notifications are off. Enable them in iPhone Settings, or tap Save again to save without reminders."
                    return
                }
            }
            do {
                // The store re-reads progress after the permission prompt, too.
                let goal = try store.saveReviewed(reviewed)
                onSave?(goal)
                dismiss()
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
}
