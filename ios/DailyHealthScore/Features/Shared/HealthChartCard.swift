import SwiftUI
import Charts

/// One Apple Health measure. The large number is the week, the bars are the days,
/// and there is no goal line: these records are not the Daily Health Score.
struct HealthChartCard: View {
    let chart: CoachHealthChart
    var compact: Bool = false

    private var average: Double {
        let values = chart.points.map(\.value)
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var top: Double {
        let highs = chart.points.map { $0.high ?? $0.value }
        let highest = highs.max() ?? 0
        return max(highest, average, 1) * 1.12
    }

    private var bottom: Double {
        let lows = chart.points.map { $0.secondary ?? $0.low ?? $0.value }
        let lowest = lows.min() ?? 0
        if lowest < 0 { return lowest * 1.12 }
        if chart.style == .bar { return 0 }
        return max(0, lowest * 0.9)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            Text(chart.title)
                .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
            Text(chart.headline)
                .font(.system(size: compact ? 28 : 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(chart.caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            marks
                .frame(height: compact ? 150 : 200)
            if chart.style != .pressure {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(AppTheme.primary)
                        .frame(width: 18, height: 3)
                    Text("Average · \(chart.headline)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(chart.title). \(chart.headline). \(chart.caption)")
    }

    private var marks: some View {
        Chart {
            if chart.style == .range {
                ForEach(chart.points) { point in
                    BarMark(
                        x: .value("Day", point.id),
                        yStart: .value("Low", point.low ?? point.value),
                        yEnd: .value("High", point.high ?? point.value)
                    )
                    .foregroundStyle(AppTheme.primary.opacity(0.35))
                    .cornerRadius(3)
                    PointMark(
                        x: .value("Day", point.id),
                        y: .value("Average", point.value)
                    )
                    .foregroundStyle(AppTheme.primary)
                }
            } else if chart.style == .pressure {
                ForEach(chart.points) { point in
                    BarMark(
                        x: .value("Reading", point.id),
                        yStart: .value("Diastolic", point.secondary ?? point.value),
                        yEnd: .value("Systolic", point.value)
                    )
                    .foregroundStyle(AppTheme.primary.opacity(0.8))
                    .cornerRadius(3)
                }
            } else {
                ForEach(chart.points) { point in
                    BarMark(
                        x: .value("Day", point.id),
                        y: .value(chart.unit, point.value)
                    )
                    .foregroundStyle(AppTheme.primary.opacity(0.8))
                    .cornerRadius(3)
                }
            }
            if chart.style != .pressure {
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(AppTheme.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartYScale(domain: bottom ... top)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(0.15))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(axisText(number))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: chart.points.map(\.id)) { value in
                AxisValueLabel {
                    if let id = value.as(String.self),
                       let point = chart.points.first(where: { $0.id == id }) {
                        Text(point.label)
                            .font(.caption2)
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }

    private func axisText(_ number: Double) -> String {
        let digits = abs(number) >= 100 || number.rounded() == number ? 0 : 1
        return String(format: "%.\(digits)f", number)
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
