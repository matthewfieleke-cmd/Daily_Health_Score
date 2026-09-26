import SwiftUI

/// Baseline questions, filed straight into the memory files. Skip anything.
/// Saving again updates the note that question already owns.
struct CoachIntakeView: View {
    @EnvironmentObject private var coach: LifestyleCoachController
    @Environment(\.dismiss) private var dismiss

    @State private var answers: [CoachIntakeField: String] = [:]

    var body: some View {
        Form {
            Section {
                Text("A baseline, so your coach knows your life before the numbers. Skip anything. You can change it later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(CoachIntakeField.groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.fields) { field in
                        fieldRow(field)
                    }
                }
            }
        }
        .navigationTitle("Intake")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Skip") {
                    coach.memory.skipIntake()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    coach.memory.saveIntake(answers)
                    dismiss()
                }
            }
        }
        .onAppear {
            if answers.isEmpty {
                answers = coach.memory.intakeAnswers()
            }
        }
    }

    private func fieldRow(_ field: CoachIntakeField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(field.title)
                .font(.subheadline.weight(.semibold))
            TextField(field.placeholder, text: binding(for: field), axis: .vertical)
                .lineLimit(1...4)
        }
        .padding(.vertical, 2)
    }

    private func binding(for field: CoachIntakeField) -> Binding<String> {
        Binding(
            get: { answers[field] ?? "" },
            set: { answers[field] = $0 }
        )
    }
}
