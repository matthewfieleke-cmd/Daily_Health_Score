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

    @EnvironmentObject private var appState: AppState
    @State private var selectedRange: HRVGraphRange = .thirty
    @State private var sensitivity: HRVSensitivity = .balanced
    @State private var showSensitivityInfo = false

    private var series: HRVTrendSeries {
        HRVTrendSeriesBuilder.build(
            records: records,
            todayKey: todayKey,
            days: selectedRange.rawValue,
            sensitivity: sensitivity
        )
    }

    private var analysis: HRVAnalysis {
        HRVBaselineAnalyzer.analyze(
            records: records,
            todayKey: todayKey,
            sensitivity: sensitivity
        )
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    rangePicker

                    if series.points.allSatisfy({ $0.rawMs == nil && $0.trendMs == nil }) {
                        emptyState
                    } else {
                        statusCard
                        chartCard
                        sensitivityCard
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("HRV")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .onAppear { sensitivity = appState.settingsStore.hrvSensitivity }
        .onChange(of: sensitivity) { _, newValue in
            appState.settingsStore.hrvSensitivity = newValue
        }
        .infoScrollDialog(
            isPresented: $showSensitivityInfo,
            title: HRVEducationLibrary.title,
            text: HRVEducationLibrary.body
        )
    }

    private var rangePicker: some View {
        Picker("Range", selection: $selectedRange) {
            ForEach(HRVGraphRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Button {
                    withAnimation { showSensitivityInfo = true }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("About your usual HRV range")
            }

            Text(statusDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
        .padding(.horizontal, 16)
    }

    private var statusColor: Color {
        switch analysis.state {
        case .buildingBaseline:
            return .secondary
        case .ready(let result):
            switch result.status {
            case .withinRange: return AppTheme.leaf
            case .belowRange, .aboveRange: return AppTheme.primary
            }
        }
    }

    private var statusTitle: String {
        switch analysis.state {
        case .buildingBaseline:
            return "Building your range"
        case .ready(let result):
            switch result.status {
            case .withinRange: return "In your usual range"
            case .belowRange: return "Below your usual range"
            case .aboveRange: return "Above your usual range"
            }
        }
    }

    private var statusDetail: String {
        switch analysis.state {
        case .buildingBaseline(let validNights):
            return "\(validNights) night\(validNights == 1 ? "" : "s") tracked so far. Keep wearing your Apple Watch during sleep — your personalized range appears after about three weeks of data."
        case .ready(let result):
            let trend = Int(result.trendMean.rounded())
            let low = Int(result.lowerBound.rounded())
            let high = Int(result.upperBound.rounded())
            var detail = "Recent 7-day average \(trend) ms · usual range \(low)–\(high) ms"
            switch result.status {
            case .withinRange:
                break
            case .belowRange:
                detail += " · often reflects strain or reduced recovery"
            case .aboveRange:
                detail += " · often reflects strong recovery"
            }
            if result.isHighVariability {
                detail += " · less consistent than usual"
            }
            return detail
        }
    }

    // MARK: - Chart

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Chart {
                ForEach(series.points) { point in
                    if let lower = point.lowerMs, let upper = point.upperMs {
                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            yStart: .value("Lower", lower),
                            yEnd: .value("Upper", upper)
                        )
                        .foregroundStyle(AppTheme.primary.opacity(0.12))
                    }
                }

                ForEach(series.points) { point in
                    if let raw = point.rawMs {
                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Nightly", raw)
                        )
                        .foregroundStyle(AppTheme.primary.opacity(0.28))
                        .symbolSize(16)
                    }
                }

                ForEach(series.points) { point in
                    if let trend = point.trendMs {
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Trend", trend),
                            series: .value("Series", "trend")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(AppTheme.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }

                if let baselineMean = series.baselineMeanMs {
                    RuleMark(y: .value("Baseline", baselineMean))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .chartYAxisLabel("ms")
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: selectedRange.xAxisStrideDays)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisLabelFormat)
                }
            }
            .frame(height: 240)

            legend
        }
        .padding(16)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
        .padding(.horizontal, 16)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: AppTheme.primary, label: "Rolling average")
            legendItem(color: AppTheme.primary.opacity(0.18), label: "Usual range")
            Spacer(minLength: 0)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 8)
            Text(label)
        }
    }

    // MARK: - Sensitivity

    private var sensitivityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sensitivity")
                .font(.footnote.weight(.semibold))

            Picker("Sensitivity", selection: $sensitivity) {
                ForEach(HRVSensitivity.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Text(sensitivity.shortDescription)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
