import SwiftUI

struct LifestyleCoachChatView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @State private var focusedGoalID: UUID?
    @State private var planningGoal = false
    @State private var goalEdit: SMARTGoalEdit?
    @State private var focus: CoachFocusContext?
    @State private var showMemory = false
    @State private var showFeedback = false
    @FocusState private var isInputFocused: Bool

    init(
        initialMessage: String = "",
        focus: CoachFocusContext? = nil,
        focusedGoalID: UUID? = nil
    ) {
        _draft = State(initialValue: initialMessage)
        _focusedGoalID = State(initialValue: focusedGoalID ?? focus?.goalId)
        _planningGoal = State(initialValue: focusedGoalID != nil || focus?.feature == .goal || initialMessage.lowercased().contains("smart goal"))
        _focus = State(initialValue: focus)
    }

    private var selectedGoal: SMARTGoal? {
        appState.smartGoalStore.goals.first { $0.id == focusedGoalID }
    }

    private var todayKey: String { DateHelpers.localDateKey() }
    private var todayRecord: DailyRecord? {
        appState.recordStore.records.first { $0.date == todayKey }
    }

    var body: some View {
        VStack(spacing: 0) {
            if coach.availability != .available {
                availabilityBanner
            }
            if let focus {
                focusBanner(focus)
            }
            if planningGoal { goalFocusBanner }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        introCard
                        ForEach(coach.memory.turns) { turn in
                            bubble(for: turn)
                                .id(turn.id)
                        }
                        if coach.isChatBusy {
                            HStack {
                                ProgressView()
                                Text("Coach is thinking…")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 4)
                            .id("pending")
                        }
                        if let proposal = coach.goalProposal, !coach.isChatBusy {
                            goalProposalCard(proposal)
                                .id("goal-proposal")
                        }
                        if let error = coach.chatError, !coach.isChatBusy,
                           coach.memory.turns.last?.role != .coach {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .id("chat-error")
                        }
                        if showFeedback {
                            CoachLocalFeedbackBar(target: "suggestion", goalId: focusedGoalID) { useful in
                                coach.recordLocalFeedback(target: "suggestion", useful: useful, goalId: focusedGoalID)
                                showFeedback = false
                            }
                        }
                    }
                    .padding(16)
                }
                .onChange(of: coach.memory.turns.count) { _, _ in
                    scrollToEnd(proxy)
                }
                .onChange(of: coach.isChatBusy) { _, busy in
                    scrollToEnd(proxy)
                }
                .onChange(of: coach.goalProposal?.id) { _, _ in
                    scrollToEnd(proxy)
                }
            }

            if let error = coach.chatError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }

            suggestionRow
            composer
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("DHS Lifestyle Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Create goal manually") { goalEdit = SMARTGoalEdit() }
                    if let selectedGoal {
                        Button("Edit this goal") { goalEdit = SMARTGoalEdit(goal: selectedGoal) }
                    }
                    Button("What your coach remembers") { showMemory = true }
                } label: {
                    Image(systemName: "target")
                }
                .accessibilityLabel("SMART goal and memory actions")
                .disabled(coach.isChatBusy)
            }
        }
        .sheet(item: $goalEdit) { edit in
            NavigationStack {
                SMARTGoalEditorView(edit: edit) { saved in
                    coach.recordGoalSaved(saved)
                    focusedGoalID = saved.id
                    planningGoal = true
                }
            }
        }
        .sheet(isPresented: $showMemory) {
            NavigationStack {
                CoachMemoryListView()
                    .environmentObject(appState)
            }
        }
        .onAppear {
            coach.refreshAvailability()
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(CoachCharter.philosophy)
                .font(.subheadline.weight(.medium))
            Text("Talk through what matters to you, formulate a SMART goal, or work through a barrier. Your coach can use your saved goals, dated check-ins, and memories you can inspect. Conversations stay in this app's local memory.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var goalFocusBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedGoal?.specificText ?? (focusedGoalID == nil ? "Plan a SMART goal" : "This goal is no longer saved"))
                    .font(.subheadline.weight(.semibold))
                if let selectedGoal {
                    Text("\(selectedGoal.filledCount) of \(selectedGoal.targetCount) check-ins · ends \(selectedGoal.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        if selectedGoal.status == .active && !selectedGoal.isComplete && !selectedGoal.isExpired {
                            Button("Log a check-in") {
                                appState.smartGoalStore.fillNextEmpty(on: selectedGoal.id, source: .iPhone)
                            }
                            .buttonStyle(.bordered)
                            .disabled(coach.isChatBusy)
                            if !selectedGoal.plan.fallbackAction.isEmpty {
                                Button("Log smaller step") {
                                    _ = appState.smartGoalStore.recordFallback(goalId: selectedGoal.id)
                                }
                                .buttonStyle(.bordered)
                                .disabled(coach.isChatBusy)
                            }
                        }
                        NavigationLink("View goal") {
                            SMARTGoalDetailView(goalId: selectedGoal.id)
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
            }
            Spacer(minLength: 0)
            Button {
                planningGoal = false
                focusedGoalID = nil
                coach.dismissGoalProposal()
            } label: { Image(systemName: "xmark.circle") }
                .accessibilityLabel("Leave goal planning")
                .disabled(coach.isChatBusy)
        }
        .padding(12)
        .background(AppTheme.primary.opacity(0.08))
    }

    private func focusBanner(_ focus: CoachFocusContext) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Talking about \(focus.title)")
                    .font(.subheadline.weight(.semibold))
                if let start = focus.startDateKey, let end = focus.endDateKey {
                    Text(start == end ? DateHelpers.formatDisplayDate(start) : "\(DateHelpers.formatDisplayDate(start)) – \(DateHelpers.formatDisplayDate(end))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !focus.valueSummary.isEmpty {
                    Text(focus.valueSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer(minLength: 0)
            Button {
                self.focus = nil
            } label: { Image(systemName: "xmark.circle") }
            .accessibilityLabel("Remove this coaching context")
            .disabled(coach.isChatBusy)
        }
        .padding(12)
        .background(AppTheme.leaf.opacity(0.10))
    }

    private func goalProposalCard(_ proposal: CoachGoalProposal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(proposal.isUpdate ? "Suggested goal changes" : "Draft SMART goal")
                .font(.headline)
            if let original = proposal.edit.original {
                Text("Currently: \(original.generatedSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(proposal.edit.summary)
                .font(.subheadline)
            Text("Review the details before saving. This is a proposal, not a saved goal. Existing check-ins are kept.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Review goal") { goalEdit = proposal.edit }
                    .buttonStyle(.borderedProminent)
                Button("Dismiss") { coach.dismissGoalProposal() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var availabilityBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coach.availability.title)
                .font(.footnote.weight(.semibold))
            Text(coach.availability.guidance)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
    }

    /// A blank text field is the hardest moment in the feature — people do not
    /// know what a coach is for until they see a good question. These are built
    /// from today's real numbers, and they get out of the way once typing starts.
    @ViewBuilder
    private var suggestionRow: some View {
        let suggestions = planningGoal ? CoachGoalPlanning.starterQuestions(for: selectedGoal) : CoachPromptSuggestions.build(
            record: todayRecord,
            goals: appState.smartGoalStore.goals
        )
        if coach.availability == .available,
           !coach.isChatBusy,
           draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !suggestions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            send(suggestion)
                        } label: {
                            Text(suggestion)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.primary.opacity(0.10))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 2)
        }
    }

    private func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !coach.isChatBusy else { return }
        planningGoal = planningGoal || CoachGoalPlanning.isGoalConversation(
            message: trimmed, focusedGoalID: focusedGoalID, hasProposal: coach.goalProposal != nil
        )
        draft = ""
        coach.beginChatSend()
        Task {
            await coach.sendChatMessage(
                trimmed,
                todayRecord: todayRecord,
                records: appState.recordStore.records,
                goals: appState.smartGoalStore.goals,
                hrvSensitivity: appState.settingsStore.hrvSensitivity,
                focusedGoalID: focusedGoalID,
                planningGoal: planningGoal,
                focus: focus,
                activities: appState.smartGoalStore.activities
            )
            showFeedback = coach.memory.turns.last?.role == .coach && coach.chatError == nil
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Ask your coach…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(AppTheme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .focused($isInputFocused)
                .lineLimit(1...5)

            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(AppTheme.primary)
            }
            .disabled(
                coach.isChatBusy
                    || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || coach.availability != .available
            )
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func bubble(for turn: CoachChatTurn) -> some View {
        HStack {
            if turn.role == .user { Spacer(minLength: 40) }
            Text(turn.text)
                .font(.body)
                .foregroundStyle(turn.role == .user ? Color.white : Color.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    turn.role == .user
                        ? AppTheme.primary
                        : AppTheme.cardSurface
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if turn.role == .coach { Spacer(minLength: 40) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            if coach.isChatBusy {
                withAnimation { proxy.scrollTo("pending", anchor: .bottom) }
            } else if coach.goalProposal != nil {
                withAnimation { proxy.scrollTo("goal-proposal", anchor: .bottom) }
            } else if let last = coach.memory.turns.last {
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }
}
