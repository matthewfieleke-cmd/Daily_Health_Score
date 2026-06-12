import Charts
import SwiftUI

private enum HRVGraphRange: Int, CaseIterable, Identifiable {
    case seven = 7
    case thirty = 30
    case ninety = 90

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .seven: return "7-Day"
        case .thirty: return "30-Day"
        case .ninety: return "90-Day"
        }
    }

    var xAxisStrideDays: Int {
        switch self {
        case .seven: return 1
        case .thirty: return 5
        case .ninety: return 14
        }
    }
}

struct HRVGraphView: View {
    let records: [DailyRecord]
    let todayKey: String

    @State private var selectedRange: HRVGraphRange = .seven

    private var series: HRVChartSeries {
        HRVChartSeriesBuilder.build(
            records: records,
            todayKey: todayKey,
            days: selectedRange.rawValue
        )
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Picker("Range", selection: $selectedRange) {
                    ForEach(HRVGraphRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if series.points.isEmpty {
                    emptyState
                } else {
                    chartCard
                }

                Spacer(minLength: 0)
            }
        }
        .navigationTitle("HRV")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let averageMs = series.averageMs {
                Text("Average: \(Int(averageMs.rounded())) ms")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(series.points) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("HRV", point.valueMs)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(AppTheme.primary)

                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("HRV", point.valueMs)
                    )
                    .foregroundStyle(AppTheme.primary)
                }

                if let averageMs = series.averageMs {
                    RuleMark(y: .value("Average", averageMs))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .chartYAxisLabel("ms")
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: selectedRange.xAxisStrideDays)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisLabelFormat)
                }
            }
            .frame(height: 240)
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
        .padding(.horizontal, 16)
    }

    private var xAxisLabelFormat: Date.FormatStyle {
        switch selectedRange {
        case .seven:
            return .dateTime.weekday(.abbreviated)
        case .thirty:
            return .dateTime.month(.abbreviated).day()
        case .ninety:
            return .dateTime.month(.abbreviated).day()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform.path.ecg")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No HRV data in this period")
                .font(.subheadline.weight(.semibold))
            Text("Wear your Apple Watch during sleep to build history.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }
}
