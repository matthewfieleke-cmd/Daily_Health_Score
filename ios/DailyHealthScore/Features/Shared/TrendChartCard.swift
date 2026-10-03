import SwiftUI
import Charts

/// The finished-day picture. Bars are days, one line is the average, the other
/// is the goal. The 30- and 90-day figures stay numbers so the chart stays readable.
struct TrendChartCard: View {
    let trend: CompletedTrend
    var compact: Bool = false

    private var averageColor: Color {
        switch trend.metric {
        case .sleep: return AppTheme.primary
        case .fiber: return AppTheme.leaf
        case .movement: return AppTheme.tint(for: .exercise)
        }
    }

    private var goalColor: Color { AppTheme.trendGoal }

    private var top: Double {
        let highestBar = trend.bars.map(\.value).max() ?? 0
        return max(trend.goal, trend.average, highestBar, 1) * 1.12
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            Text(trend.title)
                .font(compact ? .subheadline.weight(.semibold) : .title3.weight(.semibold))
            Text(trend.headline)
                .font(.system(size: compact ? 28 : 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(trend.caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            chart
                .frame(height: compact ? 140 : 190)

            legend

            if let thirty = trend.thirtyText {
                labeledLine(thirty)
            }
            if let ninety = trend.ninetyText {
                labeledLine(ninety)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trend.accessibilitySummary)
    }

    private var chart: some View {
        Chart {
            ForEach(trend.bars) { bar in
                BarMark(
                    x: .value("Day", bar.dateKey),
                    y: .value(trend.title, bar.value)
                )
                .foregroundStyle(Color.secondary.opacity(0.35))
                .cornerRadius(3)
            }
            RuleMark(y: .value("Average", trend.average))
                .foregroundStyle(averageColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            if trend.goal > 0 {
                RuleMark(y: .value("Goal", trend.goal))
                    .foregroundStyle(goalColor)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
            }
        }
        .chartYScale(domain: 0 ... top)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: trend.bars.map(\.dateKey)) { value in
                AxisValueLabel {
                    if let key = value.as(String.self),
                       let bar = trend.bars.first(where: { $0.dateKey == key }) {
                        Text(bar.label)
                            .font(.caption2)
                    }
                }
            }
        }
        .chartLegend(.hidden)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 4) {
            legendItem(color: averageColor, dashed: false, name: "Average · \(trend.headline)")
            if trend.goal > 0 {
                legendItem(color: goalColor, dashed: true, name: "Goal · \(trend.goalText)")
            }
        }
        .font(.caption.weight(.semibold))
    }

    private func legendItem(color: Color, dashed: Bool, name: String) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 3] : []))
                .frame(width: 18, height: 3)
            Text(name)
                .foregroundStyle(.secondary)
        }
    }

    private func labeledLine(_ text: String) -> some View {
        Text(text)
            .font(compact ? .caption : .subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension AppTheme {
    /// Second line on a finished-day chart. Distinct from sleep, fiber, and movement.
    static let trendGoal = Color(
        light: Color(red: 0.36, green: 0.22, blue: 0.55),
        dark: Color(red: 0.80, green: 0.66, blue: 0.93)
    )
}
