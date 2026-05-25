import SwiftUI

struct SMARTGoalsListView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showWizard = false

    private var goals: [SMARTGoal] {
        appState.smartGoalStore.goals
    }

    var body: some View {
        Group {
            if goals.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(goals) { goal in
                        NavigationLink {
                            SMARTGoalDetailView(goalId: goal.id)
                        } label: {
                            SMARTGoalRowView(goal: goal)
                        }
                    }
                    .onDelete(perform: deleteGoals)
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("SMART Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showWizard = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New SMART goal")
            }
        }
        .sheet(isPresented: $showWizard) {
            NavigationStack {
                SMARTGoalWizardView()
            }
        }
        .onAppear {
            appState.smartGoalStore.refreshEndedStatus()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.primary.opacity(0.5))
            Text("No active SMART goals")
                .font(.title3.weight(.semibold))
            Text("Create a Specific, Measurable, Achievable, Relevant, Time-bound goal to stay accountable.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button {
                showWizard = true
            } label: {
                Text("New SMART goal")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding()
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            let id = goals[index].id
            appState.smartGoalStore.delete(id: id)
        }
    }
}

private struct SMARTGoalRowView: View {
    let goal: SMARTGoal

    private var tint: Color { AppTheme.tint(for: goal.category) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(goal.category.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
                if goal.status == .ended {
                    Text("Ended")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                } else {
                    Text("\(goal.filledCount)/\(goal.targetCount)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(goal.specificText)
                .font(.subheadline.weight(.medium))
                .lineLimit(2)
            Text("Ends \(goal.endDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
