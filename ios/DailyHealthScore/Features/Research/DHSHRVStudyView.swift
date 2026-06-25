import Charts
import SwiftUI

struct DHSHRVStudyView: View {
    let records: [DailyRecord]
    let todayKey: String

    @State private var showEducation = false
    @State private var showMethods = false
    @State private var selectedWeek: Int?

    private var result: DHSHRVStudyResult? {
        DHSHRVStudyAnalyzer.analyze(records: records, todayKey: todayKey)
    }

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = proxy.size.width > proxy.size.height

            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        if let result {
                            headerCard(result)
                            summaryCard(result)
                            stackedTrendCard(result, isLandscape: isLandscape)
                            selectedWeekCard(result)
                            methodsCard
                            overlayCard(result, isLandscape: isLandscape)
                            correlationCard(result)
                            scatterplotCard(result, isLandscape: isLandscape)
                        } else {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationTitle("DHS + HRV")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { showEducation = true }
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("About heart rate variability")
            }
        }
        .infoScrollDialog(
            isPresented: $showEducation,
            title: HRVEducationLibrary.title,
            text: HRVEducationLibrary.body
        )
        .infoScrollDialog(
            isPresented: $showMethods,
            title: "How This Chart Works",
            text: methodsText
        )
    }

    private func headerCard(_ result: DHSHRVStudyResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Health Score Correlation with HRV")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(windowSubtitle(result))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation { showEducation = true }
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundStyle(AppTheme.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About heart rate variability")
            }

            Label("Rotate your phone horizontally for a wider chart view.", systemImage: "iphone.landscape")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .dhsCard()
    }

    private func summaryCard(_ result: DHSHRVStudyResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.correlation.displayLabel)
                .font(.headline.weight(.semibold))
                .foregroundStyle(summaryColor(result.correlation))

            Text(result.relationshipSummary)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("This is a personal trend view, not a diagnosis. HRV is one useful signal, and many factors can affect it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dhsCard()
    }

    private func stackedTrendCard(_ result: DHSHRVStudyResult, isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("13 Weekly Trend Points")
                .font(.headline.weight(.semibold))

            Text("Each point summarizes one 7-day block. The DHS point averages your scores from those 7 days. The HRV point averages sleep HRV from the nights that followed those same days.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 16) {
                weeklyLineChart(
                    result.weeklyPoints,
                    title: "DHS",
                    value: \.averageDHS,
                    completeness: \.dhsCompleteness,
                    color: AppTheme.primary,
                    yLabel: "Score",
                    height: isLandscape ? 210 : 160
                )

                weeklyLineChart(
                    result.weeklyPoints,
                    title: "Following-Night HRV",
                    value: \.averageHRV,
                    completeness: \.hrvCompleteness,
                    color: AppTheme.leaf,
                    yLabel: "ms",
                    height: isLandscape ? 210 : 160
                )
            }

            legend
        }
        .dhsCard()
    }

    private func weeklyLineChart(
        _ points: [DHSHRVWeeklyPoint],
        title: String,
        value: KeyPath<DHSHRVWeeklyPoint, Double?>,
        completeness: KeyPath<DHSHRVWeeklyPoint, StudyPointCompleteness>,
        color: Color,
        yLabel: String,
        height: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Chart {
                ForEach(points) { point in
                    if let y = point[keyPath: value] {
                        LineMark(
                            x: .value("Week", point.weekIndex),
                            y: .value(title, y),
                            series: .value("Series", title)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))

                        PointMark(
                            x: .value("Week", point.weekIndex),
                            y: .value(title, y)
                        )
                        .foregroundStyle(point[keyPath: completeness] == .sparse ? color.opacity(0.38) : color)
                        .symbolSize(point[keyPath: completeness] == .sparse ? 32 : 48)
                    }
                }
            }
            .chartYAxisLabel(yLabel)
            .chartXAxis { weekAxisMarks }
            .chartXSelection(value: $selectedWeek)
            .frame(height: height)
        }
    }

    private var weekAxisMarks: some AxisContent {
        AxisMarks(values: Array(1 ... DHSHRVStudyResult.weeklyPointCount)) { value in
            AxisGridLine()
            AxisTick()
            if let week = value.as(Int.self) {
                AxisValueLabel("W\(week)")
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: AppTheme.primary, label: "DHS")
            legendItem(color: AppTheme.leaf, label: "HRV")
            legendItem(color: .secondary.opacity(0.35), label: "1-3 values")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }

    @ViewBuilder
    private func selectedWeekCard(_ result: DHSHRVStudyResult) -> some View {
        if let selectedWeek,
           let point = result.weeklyPoints.first(where: { $0.weekIndex == selectedWeek }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Week \(point.weekIndex)")
                    .font(.subheadline.weight(.semibold))
                Text("\(formatRange(point.dhsStartDate, point.dhsEndDate)) DHS paired with \(formatRange(point.hrvStartDate, point.hrvEndDate)) sleep HRV")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let averageDHS = point.averageDHS {
                    Text("DHS average: \(ScoreCalculator.formatDisplayScore(averageDHS)) based on \(point.dhsValueCount) of 7 days.")
                        .font(.caption)
                }
                if let averageHRV = point.averageHRV {
                    Text("HRV average: \(Int(averageHRV.rounded())) ms based on \(point.hrvValueCount) of 7 nights.")
                        .font(.caption)
                }
            }
            .dhsCard(padding: 14)
        }
    }

    private var methodsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("How the Trend Is Built")
                    .font(.headline.weight(.semibold))
                Spacer(minLength: 0)
                Button("Learn more") {
                    withAnimation { showMethods = true }
                }
                .font(.caption.weight(.semibold))
            }

            Text("We use your latest 91 complete DHS days, pair each day with the sleep HRV from the night that followed it, then group those 91 pairs into 13 weekly points.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dhsCard()
    }

    private func overlayCard(_ result: DHSHRVStudyResult, isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Do They Rise and Fall Together?")
                .font(.headline.weight(.semibold))

            Text("This view puts DHS and HRV on the same personal scale. Values above zero are above your 91-day average; values below zero are below your 91-day average.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Chart {
                ForEach(result.zScorePoints) { point in
                    LineMark(
                        x: .value("Week", point.weekIndex),
                        y: .value("Z-score", point.zScore),
                        series: .value("Series", point.series)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(by: .value("Series", point.series))
                    .lineStyle(StrokeStyle(lineWidth: 2.4))
                }
            }
            .chartForegroundStyleScale(["DHS": AppTheme.primary, "HRV": AppTheme.leaf])
            .chartYAxisLabel("Relative to average")
            .chartXAxis { weekAxisMarks }
            .frame(height: isLandscape ? 260 : 220)
        }
        .dhsCard()
    }

    private func correlationCard(_ result: DHSHRVStudyResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Correlation Summary")
                .font(.headline.weight(.semibold))

            HStack(spacing: 12) {
                statisticPill(
                    title: "Spearman",
                    value: result.correlation.spearman,
                    subtitle: "Do the trends move in the same direction?"
                )
                statisticPill(
                    title: "Pearson",
                    value: result.correlation.pearson,
                    subtitle: "How straight-line is the relationship?"
                )
            }

            Text("Spearman is the main result because it asks whether the two weekly trends generally rise and fall together. Pearson is a helpful secondary check for a straight-line pattern.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dhsCard()
    }

    private func statisticPill(title: String, value: Double?, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.map { String(format: "%.2f", $0) } ?? "--")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func scatterplotCard(_ result: DHSHRVStudyResult, isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Points Scatterplot")
                .font(.headline.weight(.semibold))

            Text("Each dot is one 7-day block. Dots that rise from lower-left to upper-right suggest higher DHS weeks tend to align with higher HRV weeks.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Chart {
                ForEach(result.scatterPoints) { point in
                    PointMark(
                        x: .value("DHS", point.averageDHS),
                        y: .value("HRV", point.averageHRV)
                    )
                    .foregroundStyle(AppTheme.primary)
                    .symbolSize(52)
                    .annotation(position: .top, alignment: .center) {
                        Text("\(point.weekIndex)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartXAxisLabel("Weekly DHS")
            .chartYAxisLabel("Weekly HRV (ms)")
            .frame(height: isLandscape ? 260 : 220)
        }
        .dhsCard()
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Building your DHS-HRV study")
                .font(.headline.weight(.semibold))
            Text("Once the app has enough dated DHS and sleep HRV records, this screen will compare 13 weekly trend points across your latest 91 complete DHS days.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .dhsCard()
    }

    private func summaryColor(_ correlation: DHSHRVCorrelationResult) -> Color {
        switch correlation.direction {
        case "positive": return AppTheme.leaf
        case "negative": return Color(red: 0.94, green: 0.55, blue: 0.32)
        default: return .primary
        }
    }

    private func windowSubtitle(_ result: DHSHRVStudyResult) -> String {
        "\(formatRange(result.dhsStartDate, result.dhsEndDate)) DHS paired with \(formatRange(result.hrvStartDate, result.hrvEndDate)) sleep HRV"
    }

    private func formatRange(_ start: String, _ end: String) -> String {
        guard let startDate = DateHelpers.date(from: start),
              let endDate = DateHelpers.date(from: end) else {
            return "\(start)-\(end)"
        }
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(startDate.formatted(format))-\(endDate.formatted(format))"
    }

    private var methodsText: String {
        """
We use your latest 91 complete DHS days.

Each DHS day is paired with the sleep HRV from the night that followed it.

Those 91 pairs are grouped into 13 weekly blocks.

Each point on the chart is one 7-day block.

The goal is to see whether your DHS and HRV trends rise and fall together over time.
"""
    }
}
