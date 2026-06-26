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
                            alignmentOverTimeCard(result, isLandscape: isLandscape)
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

            if result.correlation.direction == "positive" {
                whyThisMatters(
                    "Positive HRV trends are encouraging because higher HRV has been linked in research with better cardiovascular fitness, greater stress resilience, and lower risk of cardiovascular disease."
                )
            }
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

            whyThisMatters(
                "Weekly averages reduce day-to-day noise and help you see whether healthier DHS weeks line up with higher sleep HRV from the nights that followed those same days."
            )
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

            whyThisMatters(
                "Putting both trends on the same personal scale makes shared rises and dips easier to spot, even though DHS and HRV use different units."
            )
        }
        .dhsCard()
    }

    private func correlationCard(_ result: DHSHRVStudyResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Correlation Summary")
                .font(.headline.weight(.semibold))

            VStack(spacing: 10) {
                statisticPill(
                    title: "Spearman: do the trends move together?",
                    value: result.correlation.spearman,
                    change: result.spearmanChange,
                    subtitle: "Spearman looks at the order of your 13 weekly points. If higher-DHS weeks also tend to be higher-HRV weeks, Spearman moves upward."
                )
                statisticPill(
                    title: "Pearson: how straight is the relationship?",
                    value: result.correlation.pearson,
                    change: result.pearsonChange,
                    subtitle: "Pearson looks at the exact values and asks whether the weekly points form a straight-line pattern. It can move more when one week is unusual."
                )
            }

            Text("When these values rise, the current 91-day window is showing a more positive DHS-HRV relationship. When they fall, the relationship is weaker, noisier, or less positive.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            whyThisMatters(
                "A positive relationship means higher-DHS weeks tended to align with higher sleep HRV. That is encouraging because higher HRV is associated with healthier autonomic and cardiovascular patterns."
            )
        }
        .dhsCard()
    }

    private func statisticPill(title: String, value: Double?, change: DHSHRVCorrelationChange, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(value.map { String(format: "%.2f", $0) } ?? "--")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                if let formattedDelta = change.formattedDelta {
                    Text(formattedDelta)
                        .font(.caption.weight(.bold))
                        .foregroundStyle((change.delta ?? 0) >= 0 ? AppTheme.leaf : Color(red: 0.94, green: 0.55, blue: 0.32))
                        .monospacedDigit()
                }
            }
            Text(change.directionText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
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

    private func alignmentOverTimeCard(_ result: DHSHRVStudyResult, isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DHS-HRV Alignment Over Time")
                .font(.headline.weight(.semibold))

            Text("This repeats the same 91-day analysis across the last 30 available windows. It shows whether the relationship is staying positive, strengthening, weakening, or bouncing around.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Chart {
                ForEach(result.alignmentPoints) { point in
                    if let spearman = point.spearman {
                        LineMark(
                            x: .value("Window", point.index),
                            y: .value("Spearman", spearman),
                            series: .value("Series", "Spearman")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(by: .value("Series", "Spearman"))
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                    if let pearson = point.pearson {
                        LineMark(
                            x: .value("Window", point.index),
                            y: .value("Pearson", pearson),
                            series: .value("Series", "Pearson")
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(by: .value("Series", "Pearson"))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    }
                }
                RuleMark(y: .value("No relationship", 0))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .chartForegroundStyleScale(["Spearman": AppTheme.primary, "Pearson": AppTheme.leaf])
            .chartYAxisLabel("Correlation")
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .frame(height: isLandscape ? 260 : 220)

            alignmentCallout(result)
        }
        .dhsCard()
    }

    private func alignmentCallout(_ result: DHSHRVStudyResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Why this matters", systemImage: "heart.text.square.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(result.alignmentSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.leaf.opacity(0.10))
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

            whyThisMatters(
                "This directly checks whether your higher-DHS weeks were also higher-HRV weeks, instead of relying only on the line graphs."
            )
        }
        .dhsCard()
    }

    private func whyThisMatters(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Why this matters")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.primary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

Spearman asks whether higher-DHS weeks generally rank with higher-HRV weeks.

Pearson asks whether the weekly points form a straighter line.

The alignment-over-time chart repeats the same calculation across recent 91-day windows so you can see whether the relationship is stable or changing.
"""
    }
}
