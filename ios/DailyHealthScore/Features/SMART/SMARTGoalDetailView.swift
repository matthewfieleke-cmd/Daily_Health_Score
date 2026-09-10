import SwiftUI

struct SMARTGoalDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let goalId: UUID

    @State private var goal: SMARTGoal?
    @State private var showCelebration = false
    @State private var edit: SMARTGoalEdit?
    @State private var showCoach = false

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
                    .environmentObject(appState.coach)
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
        }
        .dhsCard(padding: 14)
    }

    private func handleCircleTap(index: Int) {
        guard var current = appState.smartGoalStore.goals.first(where: { $0.id == goalId }),
              current.status == .active, !current.isExpired else { return }

        let shouldFill = !current.isFilled(index)
        current.setFilled(index, filled: shouldFill)
        if current.isComplete {
            goal = current
            appState.smartGoalStore.save(current)
            showCelebration = true
        } else {
            persist(current)
        }
    }

    private func persist(_ updated: SMARTGoal) {
        goal = updated
        appState.smartGoalStore.save(updated)
    }
}
