import SwiftUI

/// A full chart of one Apple Health measure. Close returns to the screen that opened it.
struct HealthChartScreen: View {
    @Environment(\.dismiss) private var dismiss

    let measure: CoachHealthMeasure
    var endingOn: String = DateHelpers.localDateKey()

    @State private var chart: CoachHealthChart?
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let chart {
                    HealthChartCard(chart: chart)
                } else if loaded {
                    ContentUnavailableView(
                        "No record",
                        systemImage: "chart.bar",
                        description: Text("Apple Health has no \(measure.title.lowercased()) in this window.")
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 180)
                }
            }
            .padding(20)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle(measure.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            chart = await HealthKitService.shared.coachHealthChart(measure: measure, endingOn: endingOn)
            loaded = true
        }
    }
}
