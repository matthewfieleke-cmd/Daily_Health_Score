import SwiftUI

struct SMARTGoalDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let goalId: UUID

    @State private var goal: SMARTGoal?
    @State private var showCelebration = false
    /// When true, leaving this screen while the goal is still fully checked removes it.
    @State private var removeIfCompleteOnLeave = false

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
                }
                .padding()
            }
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Goal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .onDisappear {
            finalizeIfCompleteOnLeave()
        }
        .goalCompleteCelebration(
            isPresented: $showCelebration,
            goalTitle: goal?.specificText ?? "your goal",
            onEdit: {
                // Stay on the detail screen; bubbles remain freely editable.
            },
            onDone: {
                finishAndRemove()
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
            Text("Ended — Renew or delete?")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 12) {
                Button("Renew") {
                    removeIfCompleteOnLeave = false
                    appState.smartGoalStore.renew(cloning: goal)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primary)

                Button("Delete", role: .destructive) {
                    removeIfCompleteOnLeave = false
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

    @ViewBuilder
    private func checkInSection(_ goal: SMARTGoal) -> some View {
        if goal.status == .active && !goal.isExpired {
            VStack(alignment: .leading, spacing: 12) {
                Text("Check-ins")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                CheckInCirclesView(
                    targetCount: goal.targetCount,
                    filledMask: goal.filledMask,
                    tint: tint,
                    enabled: true,
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
    }

    private func handleCircleTap(index: Int) {
        guard var current = goal, current.status == .active, !current.isExpired else { return }

        let shouldFill = !current.isFilled(index)
        current.setFilled(index, filled: shouldFill)
        if current.isComplete {
            goal = current
            appState.smartGoalStore.save(current)
            removeIfCompleteOnLeave = true
            showCelebration = true
        } else {
            removeIfCompleteOnLeave = false
            persist(current)
        }
    }

    private func persist(_ updated: SMARTGoal) {
        goal = updated
        appState.smartGoalStore.save(updated)
    }

    private func finishAndRemove() {
        removeIfCompleteOnLeave = false
        appState.smartGoalStore.completeAndRemove(id: goalId)
        dismiss()
    }

    private func finalizeIfCompleteOnLeave() {
        guard removeIfCompleteOnLeave else { return }
        guard let current = goal, current.status == .active, current.isComplete else { return }
        appState.smartGoalStore.completeAndRemove(id: goalId)
    }
}
