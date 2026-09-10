import SwiftUI

struct SMARTGoalsListView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SMARTGoalsListContent(store: appState.smartGoalStore)
            .environmentObject(appState)
    }
}

private struct SMARTGoalsListContent: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var store: SMARTGoalStore
    @State private var showWizard = false
    @State private var edit: SMARTGoalEdit?
    @State private var showCoach = false

    private var goals: [SMARTGoal] {
        store.goals
    }

    var body: some View {
        Group {
            if goals.isEmpty {
                emptyState
            } else {
                List {
                    Button {
                        showCoach = true
                    } label: {
                        Label("Build a goal with Coach", systemImage: "bubble.left.and.text.bubble.right")
                    }
                    ForEach(goals) { goal in
                        NavigationLink {
                            SMARTGoalDetailView(goalId: goal.id)
                        } label: {
                            SMARTGoalRowView(goal: goal)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button("Edit") { edit = SMARTGoalEdit(goal: goal) }
                                .tint(AppTheme.primary)
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
        .sheet(item: $edit) { draft in
            NavigationStack { SMARTGoalEditorView(edit: draft) }
        }
        .sheet(isPresented: $showCoach) {
            NavigationStack {
                LifestyleCoachChatView(initialMessage: "Help me formulate a SMART goal")
                    .environmentObject(appState)
                    .environmentObject(appState.coach)
            }
        }
        .onAppear {
            store.refreshEndedStatus()
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
            Button("Build a goal with Coach") { showCoach = true }
                .buttonStyle(.bordered)
            Spacer()
        }
        .padding()
    }

    private func deleteGoals(at offsets: IndexSet) {
        for index in offsets {
            let id = goals[index].id
            store.delete(id: id)
        }
    }
}

private struct SMARTGoalRowView: View {
    let goal: SMARTGoal

    private var tint: Color { AppTheme.tint(for: goal.relevantTheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: goal.relevantTheme.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
                if goal.isComplete {
                    Text("Complete")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                } else if goal.status == .ended {
                    Text("Ended")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                } else if goal.isPaused {
                    Text("Paused")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
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
