import SwiftUI
import Charts

/// One Apple Health measure. Days with no record are left out, and there is
/// no goal line: these records are not the Daily Health Score.
struct HealthChartCard: View {
    let chart: CoachHealthChart
    var compact: Bool = false

    private var top: Double {
        let highest = chart.points.map(\.value).max() ?? 0
        let lowest = chart.points.map(\.value).min() ?? 0
        if lowest < 0 {
            return max(abs(highest), abs(lowest), 0.1) * 1.2
        }
        return max(highest, 1) * 1.12
    }

    private var bottom: Double {
        let lowest = chart.points.map(\.value).min() ?? 0
        return lowest < 0 ? -top : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            Text(chart.title)
                .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
            Text(chart.headline)
                .font(.system(size: compact ? 22 : 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(chart.caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            chartMarks
                .frame(height: compact ? 140 : 190)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(chart.title). \(chart.headline). \(chart.caption)")
    }

    private var chartMarks: some View {
        Chart {
            ForEach(chart.points) { point in
                BarMark(
                    x: .value("Day", point.dateKey),
                    y: .value(chart.title, point.value)
                )
                .foregroundStyle(AppTheme.primary.opacity(0.85))
                .cornerRadius(3)
            }
        }
        .chartYScale(domain: bottom ... top)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: chart.points.map(\.dateKey)) { value in
                AxisValueLabel {
                    if let key = value.as(String.self),
                       let point = chart.points.first(where: { $0.dateKey == key }) {
                        Text(point.label)
                            .font(.caption2)
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }
}

/// Compact chart under a chat reply. The reading happens when the bubble appears.
struct HealthChartBubble: View {
    let measure: CoachHealthMeasure
    var onEnlarge: () -> Void
    @State private var chart: CoachHealthChart?

    var body: some View {
        Group {
            if let chart {
                Button(action: onEnlarge) {
                    HealthChartCard(chart: chart, compact: true)
                        .padding(12)
                        .background(AppTheme.cardSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Enlarges the chart. Close returns to this chat.")
            }
        }
        .task {
            chart = await HealthKitService.shared.coachHealthChart(measure: measure)
        }
    }
}
