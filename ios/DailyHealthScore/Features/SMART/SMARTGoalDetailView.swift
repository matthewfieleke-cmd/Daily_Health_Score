import SwiftUI

struct SMARTGoalDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let goalId: UUID

    @State private var goal: SMARTGoal?
    @State private var showCelebration = false
    @State private var edit: SMARTGoalEdit?
    @State private var showCoach = false
    @State private var datingEvent: SMARTGoalActivity?

    private var tint: Color {
        goal.map { AppTheme.tint(for: $0.relevantTheme) } ?? AppTheme.primary
    }

    var body: some View {
        ScrollView {
            if let goal {
                VStack(alignment: .leading, spacing: 16) {
                    if goal.status == .ended {
                        endedBanner(goal)
                    }

                    header(goal)
                    Text(goal.generatedSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    checkInSection(goal)
                    planSection(goal)
                    activitySection(goal)

                    Button {
                        showCoach = true
                    } label: {
                        Label("Work on this with Coach", systemImage: "bubble.left.and.text.bubble.right")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Goal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .onChange(of: appState.smartGoalsRevision) { _, _ in reload() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    if let current = appState.smartGoalStore.goals.first(where: { $0.id == goalId }) {
                        edit = SMARTGoalEdit(goal: current)
                    }
                }
                .disabled(goal == nil)
            }
        }
        .sheet(item: $edit) { draft in
            NavigationStack {
                SMARTGoalEditorView(edit: draft) { _ in reload() }
            }
        }
        .sheet(isPresented: $showCoach) {
            NavigationStack {
                LifestyleCoachChatView(focusedGoalID: goalId)
                    .environmentObject(appState)
                    .environmentObject(appState.coach)
            }
        }
        .sheet(item: $datingEvent) { event in
            GoalEventDateCorrectionView(event: event) { date in
                _ = appState.smartGoalStore.correctOccurrence(eventId: event.id, occurredAt: date)
                reload()
            }
        }
        .goalCompleteCelebration(
            isPresented: $showCelebration,
            goalTitle: goal?.specificText ?? "your goal",
            onEdit: {
                // Stay on the detail screen; bubbles remain freely editable.
            },
            onDone: {
                // Retain the result for later editing and coach reflection.
                dismiss()
            }
        )
    }

    private func reload() {
        appState.smartGoalStore.refreshEndedStatus()
        goal = appState.smartGoalStore.goals.first { $0.id == goalId }
    }

    private func header(_ goal: SMARTGoal) -> some View {
        HStack(spacing: 10) {
            Image(systemName: goal.relevantTheme.systemImage)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.relevantTheme.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(goal.specificText)
                    .font(.headline)
            }
            Spacer(minLength: 0)
        }
    }

    private func endedBanner(_ goal: SMARTGoal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Goal window ended")
                .font(.subheadline.weight(.semibold))
            Text("Edit the deadline to continue with your progress, or renew to start a new goal.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Renew") {
                    appState.smartGoalStore.renew(cloning: goal)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)

                Button("Delete", role: .destructive) {
                    appState.smartGoalStore.delete(id: goal.id)
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func checkInSection(_ goal: SMARTGoal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Check-ins")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            CheckInCirclesView(
                targetCount: goal.targetCount,
                filledMask: goal.filledMask,
                tint: tint,
                enabled: goal.status == .active && !goal.isExpired,
                onTap: { index in
                    handleCircleTap(index: index)
                }
            )

            Text("\(goal.filledCount) of \(goal.targetCount) complete")
                .font(.caption)
                .foregroundStyle(.secondary)

            if goal.isPaused {
                Text("This goal is paused. Reminders and Watch check-ins wait until you resume.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !goal.plan.fallbackAction.isEmpty, goal.canLogCheckIn {
                Button("Log smaller step: \(goal.plan.fallbackAction)") {
                    _ = appState.smartGoalStore.recordFallback(goalId: goal.id)
                    reload()
                }
                .buttonStyle(.bordered)
                Text("This records the fallback only. It does not count toward \(goal.specificText).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .dhsCard(padding: 14)
    }

    private func planSection(_ goal: SMARTGoal) -> some View {
        let lines = goal.plan.promptLines()
        return Group {
            if !lines.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your plan")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    ForEach(lines, id: \.self) { line in
                        Text(line)
                            .font(.subheadline)
                    }
                }
                .dhsCard(padding: 14)
            }
        }
    }

    private func activitySection(_ goal: SMARTGoal) -> some View {
        let events = appState.smartGoalStore.activities(for: goal.id)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Activity")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            if events.isEmpty {
                Text("No dated check-ins yet. Earlier progress without dates stays undated until you add one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(events.reversed()) { event in
                    activityRow(event, goal: goal)
                }
            }
            if goal.status == .active || goal.isPaused {
                reflectionComposer(goal)
            }
        }
        .dhsCard(padding: 14)
    }

    private func activityRow(_ event: SMARTGoalActivity, goal: SMARTGoal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(activityTitle(event))
                .font(.subheadline.weight(.medium))
            Text(activitySubtitle(event))
                .font(.caption)
                .foregroundStyle(.secondary)
            if event.kind == .checkIn || event.kind == .fallbackCheckIn,
               SMARTGoalActivityLogic.undoneIDs(in: appState.smartGoalStore.activities(for: goal.id)).contains(event.id) == false,
               goal.status == .active {
                HStack {
                    if !event.hasKnownOccurrenceDate {
                        Button("Add action date") {
                            datingEvent = event
                        }
                        .font(.caption.weight(.semibold))
                    }
                    Button("Undo") {
                        _ = appState.smartGoalStore.undo(eventId: event.id)
                        reload()
                    }
                    .font(.caption.weight(.semibold))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func activityTitle(_ event: SMARTGoalActivity) -> String {
        switch event.kind {
        case .checkIn: return event.hasKnownOccurrenceDate ? "Check-in" : "Check-in (date unknown)"
        case .fallbackCheckIn: return "Smaller fallback"
        case .undo: return "Undo"
        case .correction: return "Date correction"
        case .reflection: return "Reflection"
        case .revision: return "Plan revision"
        }
    }

    private func activitySubtitle(_ event: SMARTGoalActivity) -> String {
        var parts = [event.sourceLabel]
        if let occurred = event.occurredAt {
            parts.append(occurred.formatted(date: .abbreviated, time: .shortened))
        } else {
            parts.append("No action date")
        }
        if !event.note.isEmpty { parts.append(event.note) }
        if !event.reflectionText.isEmpty { parts.append(event.reflectionText) }
        return parts.joined(separator: " · ")
    }

    private func reflectionComposer(_ goal: SMARTGoal) -> some View {
        ReflectionField(goalId: goal.id) { text in
            _ = appState.smartGoalStore.addReflection(goalId: goal.id, text: text)
            reload()
        }
    }

    private func handleCircleTap(index: Int) {
        guard let current = appState.smartGoalStore.goals.first(where: { $0.id == goalId }),
              current.canLogCheckIn || current.isFilled(index) else { return }

        if current.isFilled(index) {
            _ = appState.smartGoalStore.undoCheckIn(goalId: goalId, visualIndex: index)
            reload()
            return
        }
        _ = appState.smartGoalStore.recordCheckIn(
            goalId: goalId,
            source: .iPhone,
            occurredAt: Date()
        )
        reload()
        if appState.smartGoalStore.goals.first(where: { $0.id == goalId })?.isComplete == true {
            showCelebration = true
        }
    }
}

private struct ReflectionField: View {
    let goalId: UUID
    var onSave: (String) -> Void
    @State private var text = ""
    @State private var askedFeedback = false
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What helped or got in the way?")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField("Optional reflection", text: $text, axis: .vertical)
                .lineLimit(2...4)
            Button("Save reflection") {
                onSave(text)
                text = ""
                askedFeedback = true
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if askedFeedback {
                CoachLocalFeedbackBar(target: "reflection", goalId: goalId) { useful in
                    appState.coach.recordLocalFeedback(target: "reflection", useful: useful, goalId: goalId)
                    askedFeedback = false
                }
            }
        }
    }
}

private struct GoalEventDateCorrectionView: View {
    let event: SMARTGoalActivity
    var onSave: (Date) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    init(event: SMARTGoalActivity, onSave: @escaping (Date) -> Void) {
        self.event = event
        self.onSave = onSave
        _date = State(initialValue: event.occurredAt ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("When it happened", selection: $date, displayedComponents: [.date, .hourAndMinute])
                Text("Use the time you did the action. Delivery or migration time is not the action time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Action date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(date)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
