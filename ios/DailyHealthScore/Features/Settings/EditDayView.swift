import SwiftUI

struct EditDayView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var dateKey = DateHelpers.localDateKey()
    @State private var sleepHours = ""
    @State private var fiberGrams = ""
    @State private var exerciseMinutes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Date") {
                    TextField("yyyy-MM-dd", text: $dateKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Metrics") {
                    TextField("Sleep hours", text: $sleepHours)
                        .keyboardType(.decimalPad)
                    TextField("Fiber grams", text: $fiberGrams)
                        .keyboardType(.decimalPad)
                    TextField("Exercise minutes", text: $exerciseMinutes)
                        .keyboardType(.decimalPad)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Adjust a saved day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
    }

    private func save() {
        guard DateHelpers.date(from: dateKey) != nil else {
            errorMessage = "Use date format yyyy-MM-dd."
            return
        }
        guard let sleep = Double(sleepHours), sleep >= 0,
              let fiber = Double(fiberGrams), fiber >= 0,
              let exercise = Double(exerciseMinutes), exercise >= 0 else {
            errorMessage = "Enter valid non-negative numbers."
            return
        }
        appState.saveManualDay(
            date: dateKey,
            metrics: DailyMetrics(sleepHours: sleep, fiberGrams: fiber, exerciseMinutes: exercise)
        )
        dismiss()
    }
}
