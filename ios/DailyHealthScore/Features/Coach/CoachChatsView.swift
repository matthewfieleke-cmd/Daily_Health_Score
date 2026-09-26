import SwiftUI

/// Every chat with the Coach in one list, the way Messages does it: newest
/// first, grouped by day, a title the Coach wrote, the last line, and a time.
struct CoachChatsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController
    @Environment(\.dismiss) private var dismiss

    @State private var opened: CoachChatLaunch?
    @State private var pendingDelete: CoachThread?
    @State private var showMemory = false
    @State private var showIntake = false

    private var sections: [CoachThreadSection] {
        CoachThreadLogic.sections(coach.memory.threads)
    }

    var body: some View {
        List {
            if coach.memory.needsAcquaintance {
                Section {
                    acquaintCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            ForEach(sections) { section in
                Section {
                    ForEach(section.threads) { thread in
                        Button {
                            opened = .thread(thread.id)
                        } label: {
                            CoachChatRow(thread: thread)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                pendingDelete = thread
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(section.group.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .scrollContentBackground(.hidden)
        .overlay {
            if sections.isEmpty, !coach.memory.needsAcquaintance {
                emptyState
            }
        }
        .navigationTitle("Coach")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showMemory = true
                } label: {
                    Image(systemName: "brain.head.profile")
                }
                .accessibilityLabel("What your coach remembers")
                Button {
                    opened = .newChat
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("New chat")
            }
        }
        .onAppear {
            coach.refreshAvailability()
            coach.memory.open(.chats)
            if !coach.isChatBusy {
                coach.memory.keepTheMoreSpecificNotes()
            }
        }
        .sheet(item: $opened) { launch in
            NavigationStack {
                LifestyleCoachChatView(launch: launch)
                    .environmentObject(appState)
                    .environmentObject(coach)
            }
        }
        .sheet(isPresented: $showMemory) {
            NavigationStack {
                CoachMemoryListView()
                    .environmentObject(appState)
            }
        }
        .sheet(isPresented: $showIntake) {
            NavigationStack {
                CoachIntakeView()
                    .environmentObject(appState)
                    .environmentObject(coach)
            }
        }
        .alert(
            "Delete this chat?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { thread in
            Button("Delete", role: .destructive) {
                coach.forgetSession(for: thread.id)
                coach.memory.deleteThread(thread.id)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { thread in
            Text("“\(thread.title)” is removed from your chats. What your coach learned from it stays in memory.")
        }
    }

    private var acquaintCard: some View {
        Button {
            showIntake = true
        } label: {
            HStack(spacing: 12) {
                Image("DHSLifestyleCoach")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Intake")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("A short form so your coach knows your life before the numbers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(AppTheme.primary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image("DHSLifestyleCoach")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)
            Text("No chats yet")
                .font(.headline)
            Text(CoachCharter.philosophy)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                opened = .newChat
            } label: {
                Label("New chat", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One row: pillar glyph, Coach-written title, last line, Messages-style time.
struct CoachChatRow: View {
    let thread: CoachThread
    var now: Date = Date()

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.16))
                Image(systemName: thread.pillar.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(thread.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(CoachThreadLogic.timeLabel(for: thread.lastMessageAt, now: now))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                Text(thread.preview.isEmpty ? "No messages yet" : thread.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(thread.title), \(CoachThreadLogic.timeLabel(for: thread.lastMessageAt, now: now)). \(thread.preview)")
    }

    private var tint: Color {
        switch thread.pillar {
        case .general: return AppTheme.primary
        case .relationships: return Color(red: 0.85, green: 0.45, blue: 0.55)
        case .nutrition: return AppTheme.leaf
        case .sleep: return Color(red: 0.45, green: 0.47, blue: 0.86)
        case .activity: return Color(red: 0.94, green: 0.55, blue: 0.32)
        case .stress: return Color(red: 0.30, green: 0.65, blue: 0.70)
        case .hobbies: return Color(red: 0.80, green: 0.60, blue: 0.20)
        }
    }
}
