import SwiftUI

struct EditDayView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var dateKey = DateHelpers.localDateKey()
    @State private var sleepHours = ""
    @State private var fiberGrams = ""
    @State private var movementValue = ""
    @State private var errorMessage: String?

    private var movementGoal: MovementGoal {
        appState.settingsStore.settings.movementGoal
    }

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
                    TextField(movementGoal.metricName, text: $movementValue)
                        .keyboardType(movementGoal.countsSteps ? .numberPad : .decimalPad)
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
              let movement = Double(movementValue), movement >= 0 else {
            errorMessage = "Enter valid non-negative numbers."
            return
        }
        let existing = appState.recordStore.records.first { $0.date == dateKey }
        appState.saveManualDay(
            date: dateKey,
            metrics: DailyMetrics(
                sleepHours: sleep,
                fiberGrams: fiber,
                exerciseMinutes: movementGoal.countsSteps ? (existing?.exerciseMinutes ?? 0) : movement,
                stepCount: movementGoal.countsSteps ? movement : (existing?.stepCount ?? 0)
            )
        )
        dismiss()
    }
}
