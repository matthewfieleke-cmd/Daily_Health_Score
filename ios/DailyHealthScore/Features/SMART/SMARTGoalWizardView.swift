import SwiftUI

struct SMARTGoalWizardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var draft = SMARTGoalDraft()
    @State private var notificationsAuthorized = false
    @State private var checkedNotificationStatus = false

    var body: some View {
        Group {
            switch draft.step {
            case .summary:
                summaryStep
            default:
                wizardStep
            }
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle(draft.step == .summary ? "Review" : "New SMART Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            if draft.step != .specific && draft.step != .summary {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { goBack() }
                }
            }
        }
        .task {
            let ok = await SMARTNotificationService.isAuthorizedForReminders()
            notificationsAuthorized = ok
            checkedNotificationStatus = true
        }
    }

    // MARK: - Steps

    private var wizardStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            progressHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    stepTitle
                    stepContent
                }
                .padding()
            }
            nextButton
        }
    }

    private var progressHeader: some View {
        HStack(spacing: 6) {
            ForEach(SMARTWizardStep.allCases.filter { $0 != .summary }) { s in
                Capsule()
                    .fill(s.rawValue <= draft.step.rawValue ? AppTheme.primary : Color(.tertiarySystemFill))
                    .frame(height: 4)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var stepTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(draft.step.letter)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primary)
            Text(draft.step.title)
                .font(.title2.weight(.semibold))
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch draft.step {
        case .specific:
            specificStep
        case .measurable:
            measurableStep
        case .achievable:
            achievableStep
        case .relevant:
            relevantStep
        case .time:
            timeStep
        case .summary:
            EmptyView()
        }
    }

    private var specificStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What exactly will you do?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("e.g. play a board game with my kids", text: $draft.specificText, axis: .vertical)
                .lineLimit(3 ... 6)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var measurableStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How many times do you want to do it?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Stepper("Times: \(draft.targetCount)", value: $draft.targetCount, in: 1 ... 30)
            Text("The action itself comes from your Specific step.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var achievableStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.primary)
            Text(SMARTGoalLogic.achievableReminder)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dhsCard()
    }

    private var relevantStep: some View {
        VStack(spacing: 8) {
            ForEach(SMARTRelevantTheme.allCases) { theme in
                Button {
                    draft.relevantTheme = theme
                } label: {
                    HStack {
                        Image(systemName: theme.systemImage)
                            .foregroundStyle(AppTheme.tint(for: theme))
                            .frame(width: 28)
                        Text(theme.label)
                            .foregroundStyle(.primary)
                        Spacer()
                        if draft.relevantTheme == theme {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var timeStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What's the time window?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Number of days", selection: $draft.timeWindowDays) {
                ForEach(SMARTGoalLogic.minTimeWindowDays ... SMARTGoalLogic.maxTimeWindowDays, id: \.self) { day in
                    Text("\(day) \(day == 1 ? "day" : "days")").tag(day)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 150)
            .clipped()

            LabeledContent("Ends") {
                Text(draft.endDatePreview.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }

            if checkedNotificationStatus && notificationsAuthorized {
                Toggle("Daily reminder", isOn: $draft.remindersEnabled)
                DatePicker(
                    "Reminder time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
            } else if checkedNotificationStatus {
                Text("Enable notifications in iPhone Settings to use daily reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                c.hour = draft.reminderHour
                c.minute = draft.reminderMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft.reminderHour = c.hour ?? 9
                draft.reminderMinute = c.minute ?? 0
            }
        )
    }

    // MARK: - Summary

    private var summaryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Review your SMART goal")
                    .font(.title2.weight(.semibold))

                ForEach(draft.summaryFields(), id: \.0) { step, label, value in
                    Button {
                        draft.step = step
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(value)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(AppTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Text(draft.generatedSummaryPreview)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Button {
                    saveGoal()
                } label: {
                    Text("Save goal")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding()
        }
    }

    private var nextButton: some View {
        Button {
            advance()
        } label: {
            Text("Continue")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canContinue ? AppTheme.primary : Color(.tertiarySystemFill))
                .foregroundStyle(canContinue ? Color.white : Color.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canContinue)
        .padding()
    }

    private var canContinue: Bool {
        switch draft.step {
        case .specific: return !draft.specificText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .measurable: return draft.targetCount >= 1
        case .achievable, .relevant, .time: return true
        case .summary: return true
        }
    }

    private func goBack() {
        guard let prev = SMARTWizardStep(rawValue: draft.step.rawValue - 1) else { return }
        draft.step = prev
    }

    private func advance() {
        if draft.step == .time {
            draft.step = .summary
            return
        }
        guard let next = SMARTWizardStep(rawValue: draft.step.rawValue + 1) else { return }
        draft.step = next
    }

    private func saveGoal() {
        var goal = draft.buildGoal()
        Task {
            if goal.remindersEnabled {
                let ok = await SMARTNotificationService.requestAuthorization()
                notificationsAuthorized = ok
                if !ok {
                    goal.remindersEnabled = false
                }
            }
            await MainActor.run {
                appState.smartGoalStore.save(goal)
                dismiss()
            }
        }
    }
}
