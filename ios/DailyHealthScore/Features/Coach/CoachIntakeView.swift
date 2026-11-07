import SwiftUI

/// One section at a time. Every question can stay blank. Saving files the
/// answers as notes. Skip marks intake done and writes nothing.
struct CoachIntakeView: View {
    @EnvironmentObject private var coach: LifestyleCoachController
    @Environment(\.dismiss) private var dismiss

    @State private var answers: [CoachIntakeField: String] = [:]
    @State private var step = 0
    @FocusState private var focused: CoachIntakeField?

    private var groups: [(title: String, detail: String, fields: [CoachIntakeField])] {
        CoachIntakeField.groups
    }

    private var isLast: Bool { step >= groups.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            progress
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if step == 0 {
                        Text("A few facts Apple Health cannot show. Skip any question.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(groups[step].title)
                            .font(.title2.weight(.semibold))
                        Text(groups[step].detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(groups[step].fields) { field in
                        question(field)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            bottomBar
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("For your coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Skip") {
                    coach.memory.skipIntake()
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

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(step + 1) of \(groups.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.16))
                    Capsule()
                        .fill(AppTheme.primary)
                        .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(groups.count))
                }
            }
            .frame(height: 4)
            .accessibilityLabel("Step \(step + 1) of \(groups.count)")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private func question(_ field: CoachIntakeField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.title)
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            TextField("", text: binding(for: field), axis: .vertical)
                .lineLimit(3...8)
                .focused($focused, equals: field)
                .padding(12)
                .background(AppTheme.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") {
                    focused = nil
                    step -= 1
                }
                .buttonStyle(.bordered)
            }
            Spacer(minLength: 0)
            Button(isLast ? "Save" : "Next") {
                focused = nil
                if isLast {
                    coach.memory.saveIntake(answers)
                    dismiss()
                } else {
                    step += 1
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(AppTheme.screenBackground)
    }

    private func binding(for field: CoachIntakeField) -> Binding<String> {
        Binding(
            get: { answers[field] ?? "" },
            set: { answers[field] = $0 }
        )
    }
}
