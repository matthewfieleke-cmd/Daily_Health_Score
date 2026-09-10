import SwiftUI

struct CoachMemoryListView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var editing: CoachMemoryItem?
    @State private var draft = ""
    @State private var draftCategory: CoachMemoryCategory = .other

    private var items: [CoachMemoryItem] {
        appState.coach.memory.memories
            .filter { !$0.isDeleted && $0.supersededById == nil }
            .sorted { ($0.lastConfirmedAt ?? $0.createdAt) > ($1.lastConfirmedAt ?? $1.createdAt) }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "Nothing saved yet",
                    systemImage: "brain.head.profile",
                    description: Text("When you tell the coach something durable, it appears here so you can correct or delete it. Health records and SMART goals are separate.")
                )
            } else {
                List {
                    ForEach(items) { item in
                        memoryRow(item)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("What your coach remembers")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $editing) { item in
            NavigationStack {
                Form {
                    Picker("Category", selection: $draftCategory) {
                        ForEach(CoachMemoryCategory.allCases) { category in
                            Text(category.label).tag(category)
                        }
                    }
                    Section("Memory") {
                        TextField("Correction", text: $draft, axis: .vertical)
                            .lineLimit(3...8)
                    }
                    Text("This correction replaces the older note. The coach will not keep the previous version as a current fact.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("Correct memory")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { editing = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            appState.coach.memory.correct(item: item, content: draft, category: draftCategory)
                            editing = nil
                        }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private func memoryRow(_ item: CoachMemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.category.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.provenance.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(item.displayContent)
                .font(.body)
            HStack {
                Text("Recorded \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let confirmed = item.lastConfirmedAt {
                    Text("Confirmed \(confirmed.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if item.isTemporary || item.confirmation == .needsReview || (item.expiresAt ?? .distantFuture) < Date() {
                Text("Does this still apply?")
                    .font(.caption.weight(.semibold))
                HStack {
                    Button("Yes, still true") {
                        appState.coach.memory.confirm(item, stillApplies: true)
                    }
                    .buttonStyle(.bordered)
                    Button("No, remove it") {
                        appState.coach.memory.confirm(item, stillApplies: false)
                    }
                    .buttonStyle(.bordered)
                }
            }
            HStack {
                Button("Correct") {
                    draft = item.displayContent
                    draftCategory = item.category
                    editing = item
                }
                Button("Delete", role: .destructive) {
                    appState.coach.memory.delete(item)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}
