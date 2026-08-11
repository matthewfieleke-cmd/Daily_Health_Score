import SwiftUI

struct LifestyleCoachChatView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    private var todayKey: String { DateHelpers.localDateKey() }
    private var todayRecord: DailyRecord? {
        appState.recordStore.records.first { $0.date == todayKey }
    }

    var body: some View {
        VStack(spacing: 0) {
            if coach.availability != .available {
                availabilityBanner
            }

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
                    }
                    .padding(16)
                }
                .onChange(of: coach.memory.turns.count) { _, _ in
                    scrollToEnd(proxy)
                }
                .onChange(of: coach.isChatBusy) { _, busy in
                    if busy { scrollToEnd(proxy) }
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
        }
        .onAppear {
            coach.refreshAvailability()
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(CoachCharter.philosophy)
                .font(.subheadline.weight(.medium))
            Text("Ask about sleep, nutrition, movement, stress, or building steady habits. Your coach can see today’s score, your goals, your SMART goals, and your HRV trend, and remembers prior chats on this device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        let suggestions = CoachPromptSuggestions.build(
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
        guard !trimmed.isEmpty else { return }
        draft = ""
        Task {
            await coach.sendChatMessage(
                trimmed,
                todayRecord: todayRecord,
                records: appState.recordStore.records,
                goals: appState.smartGoalStore.goals,
                hrvSensitivity: appState.settingsStore.hrvSensitivity
            )
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
            } else if let last = coach.memory.turns.last {
                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }
}
