import SwiftUI

struct SMARTGoalDetailView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let goalId: UUID

    @State private var goal: SMARTGoal?
    @State private var showCelebration = false

    private var tint: Color {
        goal.map { AppTheme.tint(for: $0.category) } ?? AppTheme.primary
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
        .alert("Goal complete!", isPresented: $showCelebration) {
            Button("Great") {
                appState.smartGoalStore.completeAndRemove(id: goalId)
                dismiss()
            }
        } message: {
            Text("You finished “\(goal?.specificText ?? "your goal")”. Nice work.")
        }
    }

    private func reload() {
        appState.smartGoalStore.refreshEndedStatus()
        goal = appState.smartGoalStore.goals.first { $0.id == goalId }
    }

    private func header(_ goal: SMARTGoal) -> some View {
        HStack(spacing: 10) {
            Image(systemName: goal.category.systemImage)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(goal.category.label)
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

                if goal.awaitingConfirm {
                    Button("I did it") {
                        confirmYesNo()
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .buttonStyle(.plain)
                }
            }
            .dhsCard(padding: 14)
        }
    }

    private func handleCircleTap(index: Int) {
        guard var current = goal, current.status == .active, !current.isExpired else { return }
        guard !current.isFilled(index) else { return }

        if current.isYesNoStyle {
            current.setFilled(index, filled: true)
            current.awaitingConfirm = true
            persist(current)
            return
        }

        current.setFilled(index, filled: true)
        persist(current)
        if current.isComplete {
            SMARTNotificationService.cancelReminders(for: current.id)
            showCelebration = true
        }
    }

    private func confirmYesNo() {
        guard var current = goal else { return }
        current.awaitingConfirm = false
        persist(current)
        SMARTNotificationService.cancelReminders(for: current.id)
        showCelebration = true
    }

    private func persist(_ updated: SMARTGoal) {
        goal = updated
        appState.smartGoalStore.save(updated)
    }
}
