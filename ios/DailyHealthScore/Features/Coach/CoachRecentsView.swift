import SwiftUI

/// Bevel-style inbox: recents across rooms, filters one level down.
struct CoachRecentsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController
    @Environment(\.dismiss) private var dismiss

    @State private var filter: CoachRoom?
    @State private var opened: CoachChatLaunch?

    var body: some View {
        List {
            Section {
                Button {
                    opened = .inbox
                } label: {
                    Label("What's on my mind", systemImage: CoachRoom.inbox.systemImage)
                }
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterChip(nil, title: "All")
                        ForEach(CoachRoom.desks) { room in
                            filterChip(room, title: room.label)
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Chats") {
                let rows = filteredThreads
                if rows.isEmpty {
                    Text("No chats in this shelf yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(rows) { thread in
                    Button {
                        opened = .thread(thread.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(thread.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("\(thread.room.label) · \(thread.status == .active ? "Active" : "Parked")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("DHS Lifestyle Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("What your coach remembers") {
                    appState.showCoachMemory = true
                }
            }
        }
        .onAppear {
            coach.memory.parkStaleThreads()
            coach.refreshAvailability()
        }
        .sheet(item: $opened) { launch in
            NavigationStack {
                LifestyleCoachChatView(launch: launch)
                    .environmentObject(appState)
                    .environmentObject(coach)
            }
        }
    }

    private var filteredThreads: [CoachThread] {
        let all = coach.memory.threads.sorted { $0.lastMessageAt > $1.lastMessageAt }
        guard let filter else { return all }
        return all.filter { $0.room == filter }
    }

    private func filterChip(_ room: CoachRoom?, title: String) -> some View {
        let selected = filter == room
        return Button {
            filter = room
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(selected ? AppTheme.primary.opacity(0.16) : AppTheme.primary.opacity(0.06))
                .foregroundStyle(AppTheme.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
