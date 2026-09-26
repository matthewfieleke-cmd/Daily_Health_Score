import SwiftUI

/// The memory files: what the Coach keeps about a person, by file, with every
/// recent Coach edit listed first so it can be undone in one tap.
struct CoachMemoryListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var editing: CoachMemoryItem?
    @State private var draft = ""
    @State private var draftSection: CoachMemorySection = .aboutYou
    @State private var isAddingNote = false
    @State private var newNote = ""
    @State private var newNoteSection: CoachMemorySection = .aboutYou
    @State private var background = ""
    @State private var showIntake = false

    private var store: CoachMemoryStore { appState.coach.memory }

    private var liveItems: [CoachMemoryItem] {
        store.effectiveMemories
            .sorted { ($0.lastConfirmedAt ?? $0.createdAt) > ($1.lastConfirmedAt ?? $1.createdAt) }
    }

    private struct FileGroup: Identifiable {
        var section: CoachMemorySection
        var items: [CoachMemoryItem]
        var id: CoachMemorySection { section }
    }

    private var sectionsWithItems: [FileGroup] {
        CoachMemorySection.allCases.compactMap { section in
            let rows = liveItems.filter { $0.section == section }
            return rows.isEmpty ? nil : FileGroup(section: section, items: rows)
        }
    }

    var body: some View {
        Group {
            if liveItems.isEmpty && store.recentChanges.isEmpty {
                ContentUnavailableView {
                    Label("Nothing on file yet", systemImage: "brain.head.profile")
                } description: {
                    Text("As you talk, your coach keeps short notes here — who matters to you, what helps, what gets in the way. You can edit, delete, or undo any of it. Health records and SMART goals are separate.")
                } actions: {
                    Button("Intake") { showIntake = true }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.primary)
                    Button("Add a note") { isAddingNote = true }
                        .buttonStyle(.bordered)
                }
            } else {
                List {
                    if !background.isEmpty {
                        Section {
                            Text(background)
                                .font(.subheadline)
                                .textSelection(.enabled)
                        } header: {
                            Text("Summary")
                        } footer: {
                            Text("A summary of the notes below. Coach is not given this.")
                        }
                    }
                    if !store.recentChanges.isEmpty {
                        Section {
                            ForEach(store.recentChanges) { change in
                                changeRow(change)
                            }
                        } header: {
                            Text("Recently changed by your coach")
                        } footer: {
                            Text("Undo puts a note back the way it was and tells your coach not to write it again. Notes marked as your coach’s read are guesses until you confirm them.")
                        }
                    }
                    ForEach(sectionsWithItems) { entry in
                        Section {
                            ForEach(entry.items) { item in
                                memoryRow(item)
                            }
                        } header: {
                            Label(entry.section.label, systemImage: entry.section.systemImage)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .task(id: store.memoryFingerprint) {
            if !appState.coach.isChatBusy {
                appState.coach.memory.keepTheMoreSpecificNotes()
            }
            // A changed fingerprint no longer matches the stored paragraph.
            // Clear it before the compile, so a retracted fact does not stay on screen.
            background = appState.coach.memory.compiledProfile
            appState.coach.refreshAvailability()
            await appState.coach.compileProfileIfNeeded()
            background = appState.coach.memory.compiledProfile
        }
        .navigationTitle("What your coach remembers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showIntake = true
                } label: {
                    Image(systemName: "list.clipboard")
                }
                .accessibilityLabel("Intake")
                Button {
                    isAddingNote = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add a note")
            }
        }
        .sheet(item: $editing) { item in
            NavigationStack {
                Form {
                    Picker("File", selection: $draftSection) {
                        ForEach(CoachMemorySection.allCases) { section in
                            Text(section.label).tag(section)
                        }
                    }
                    Section("Note") {
                        TextField("Correction", text: $draft, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    Text("This replaces the older note. Your coach will not keep the previous version as a current fact.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Edit note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editing = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.correct(item: item, content: draft, category: CoachMemoryCategory(section: draftSection))
                            editing = nil
                        }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $showIntake) {
            NavigationStack {
                CoachIntakeView()
                    .environmentObject(appState)
                    .environmentObject(appState.coach)
            }
        }
        .sheet(isPresented: $isAddingNote) {
            NavigationStack {
                Form {
                    Picker("File", selection: $newNoteSection) {
                        ForEach(CoachMemorySection.allCases) { section in
                            Text(section.label).tag(section)
                        }
                    }
                    Section("Note") {
                        TextField("Something your coach should know", text: $newNote, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    Text("Write it the way a note about you would read: “Works nights Tuesday through Thursday.”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Add a note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isAddingNote = false
                            newNote = ""
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            store.addNote(section: newNoteSection, content: newNote)
                            isAddingNote = false
                            newNote = ""
                        }
                        .disabled(newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func changeRow(_ change: CoachMemoryChange) -> some View {
        let source = change.threadId.flatMap { id in store.threads.first { $0.id == id }?.title }
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(change.summaryLine)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Text([
                    change.section.label,
                    source.map { "from “\($0)”" } ?? "while organizing notes",
                    change.createdAt.formatted(.relative(presentation: .named))
                ].joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("Undo") {
                store.undo(change)
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 2)
    }

    private func memoryRow(_ item: CoachMemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.displayContent)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text(item.provenance.label)
                Text("·")
                Text(item.createdAt.formatted(date: .abbreviated, time: .omitted))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            if item.provenance == .coachNoted {
                HStack {
                    Button("Confirm") {
                        store.confirmInference(item)
                    }
                    .buttonStyle(.bordered)
                    Button("Not right") {
                        store.delete(item)
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption)
            }
            if item.isTemporary || item.confirmation == .needsReview || (item.expiresAt ?? .distantFuture) < Date() {
                Text("Does this still apply?")
                    .font(.caption.weight(.semibold))
                HStack {
                    Button("Yes, still true") {
                        store.confirm(item, stillApplies: true)
                    }
                    .buttonStyle(.bordered)
                    Button("No, remove it") {
                        store.confirm(item, stillApplies: false)
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture {
            draft = item.displayContent
            draftSection = item.section
            editing = item
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                store.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                draft = item.displayContent
                draftSection = item.section
                editing = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(AppTheme.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Tap to edit. Swipe for delete.")
    }
}
