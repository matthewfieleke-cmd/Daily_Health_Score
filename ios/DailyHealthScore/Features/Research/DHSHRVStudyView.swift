import Charts
import SwiftUI

struct DHSHRVStudyView: View {
    let records: [DailyRecord]
    let todayKey: String

    @State private var showEducation = false
    @State private var showMethods = false
    @State private var selectedWeek: Int?
    @State private var popupAnchor: CGPoint?
    @State private var popupSize: CGSize = .zero

    private let cautionColor = Color(red: 0.94, green: 0.55, blue: 0.32)
    private let studySpace = "dhsStudySpace"

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
                            headlineCard(result)
                            correlationSummaryCard(result)
                            stackedTrendCard(result, isLandscape: isLandscape)
                            overlayCard(result, isLandscape: isLandscape)
                            scatterplotCard(result, isLandscape: isLandscape)
                            alignmentOverTimeCard(result, isLandscape: isLandscape)
                            methodsCard
                        } else {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }

                if let result {
                    weekPopupLayer(result)
                }
            }
            .coordinateSpace(name: studySpace)
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

    // MARK: - Header

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

    // MARK: - Headline

    private func headlineCard(_ result: DHSHRVStudyResult) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(summaryColor(result.correlation))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("The big picture")
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(result.headline)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .dhsCard()
    }

    // MARK: - Correlation summary (gauge + confidence)

    private func correlationSummaryCard(_ result: DHSHRVStudyResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("How Strong Is the Relationship?")
                    .font(.headline.weight(.semibold))
                Spacer(minLength: 0)
                Text(result.correlation.displayLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(summaryColor(result.correlation))
            }

            correlationGauge(result)

            if let confidence = result.confidence {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How sure can you be?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(confidence.rangeText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(result.significanceText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                statisticPill(
                    title: "Spearman (primary)",
                    value: result.correlation.spearman,
                    change: result.spearmanChange
                )
                statisticPill(
                    title: "Pearson (secondary)",
                    value: result.correlation.pearson,
                    change: result.pearsonChange
                )
            }

            if result.correlation.direction == "positive" {
                healthTieIn(
                    "Higher HRV trends are linked in research with better cardiovascular fitness, greater stress resilience, and lower risk of cardiovascular disease. Lower HRV has been linked with higher risk of heart disease, diabetes, and depression — so a positive DHS-HRV pattern is a genuinely good sign."
                )
            }

            interpretationBlock(
                shows: "A single score from −1 to +1 for how closely your 13 weekly DHS and HRV points move together. Spearman is primary; Pearson is a cross-check.",
                matters: "It condenses three months of paired data into one number you can track, instead of eyeballing two wiggly lines.",
                conclude: "You can say whether the weeks line up and how strongly. You cannot conclude that DHS causes HRV — this is an association in your own data, not proof of cause."
            )
        }
        .dhsCard()
    }

    private func correlationGauge(_ result: DHSHRVStudyResult) -> some View {
        let value = result.correlation.spearman
        let confidence = result.confidence

        return VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let position: (Double) -> CGFloat = { v in
                    CGFloat((max(-1, min(1, v)) + 1) / 2) * width
                }

                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        gaugeZone(cautionColor.opacity(0.55), fraction: 0.20, width: width)
                        gaugeZone(cautionColor.opacity(0.30), fraction: 0.15, width: width)
                        gaugeZone(Color.secondary.opacity(0.22), fraction: 0.30, width: width)
                        gaugeZone(AppTheme.leaf.opacity(0.45), fraction: 0.15, width: width)
                        gaugeZone(AppTheme.leaf.opacity(0.75), fraction: 0.20, width: width)
                    }
                    .frame(height: 14)
                    .clipShape(Capsule())

                    if let confidence {
                        let lo = position(confidence.lower)
                        let hi = position(confidence.upper)
                        Capsule()
                            .fill(AppTheme.primary.opacity(0.22))
                            .overlay(Capsule().stroke(AppTheme.primary.opacity(0.45), lineWidth: 1))
                            .frame(width: max(2, hi - lo), height: 14)
                            .offset(x: lo)
                    }

                    if let value {
                        Capsule()
                            .fill(.primary)
                            .frame(width: 3, height: 26)
                            .offset(x: position(value) - 1.5)
                    }
                }
                .frame(height: 26)
            }
            .frame(height: 26)

            HStack {
                Text("−1")
                Spacer()
                Text("0")
                Spacer()
                Text("+1")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text(gaugeCaption(value: value, confidence: confidence))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func gaugeZone(_ color: Color, fraction: CGFloat, width: CGFloat) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: width * fraction)
    }

    private func gaugeCaption(value: Double?, confidence: DHSHRVConfidence?) -> String {
        guard let value else {
            return "Left of center is negative, the middle band is no clear relationship, and the green zones to the right are positive."
        }
        let formatted = String(format: "%.2f", value)
        var text = "The black marker sits at your Spearman value (\(formatted)). Green zones are positive; the orange zones to the left are negative."
        if confidence != nil {
            text += " The shaded band is the likely range given only 13 weekly points."
        }
        return text
    }

    private func statisticPill(title: String, value: Double?, change: DHSHRVCorrelationChange) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(value.map { String(format: "%.2f", $0) } ?? "--")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                if let formattedDelta = change.formattedDelta {
                    Text(formattedDelta)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle((change.delta ?? 0) >= 0 ? AppTheme.leaf : cautionColor)
                        .monospacedDigit()
                }
            }
            Text(change.directionText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Weekly trend lines

    private func stackedTrendCard(_ result: DHSHRVStudyResult, isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("13 Weekly Trend Points")
                .font(.headline.weight(.semibold))

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

            interpretationBlock(
                shows: "Two stacked lines. Each point averages one 7-day block: DHS from those days, and sleep HRV from the nights that followed them. Faded points rest on only 1–3 values.",
                matters: "Weekly averaging strips out day-to-day noise so real multi-week trends become visible.",
                conclude: "You can spot whether healthier DHS weeks tend to sit alongside higher HRV weeks. Tap either chart to pull up that week's exact dates and counts. Treat faded points cautiously."
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
                if let selectedWeek {
                    RuleMark(x: .value("Week", selectedWeek))
                        .foregroundStyle(.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }

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
                        .foregroundStyle(pointColor(point, completeness: completeness, color: color))
                        .symbolSize(pointSize(point, completeness: completeness))
                    }
                }
            }
            .chartYAxisLabel(yLabel)
            .chartXAxis { weekAxisMarks }
            .chartXScale(domain: 1 ... DHSHRVStudyResult.weeklyPointCount)
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            selectWeek(at: location, points: points, value: value, proxy: proxy, geometry: geo)
                        }
                }
            }
            .frame(height: height)
        }
    }

    private func pointColor(
        _ point: DHSHRVWeeklyPoint,
        completeness: KeyPath<DHSHRVWeeklyPoint, StudyPointCompleteness>,
        color: Color
    ) -> Color {
        if point.weekIndex == selectedWeek { return color }
        return point[keyPath: completeness] == .sparse ? color.opacity(0.38) : color
    }

    private func pointSize(
        _ point: DHSHRVWeeklyPoint,
        completeness: KeyPath<DHSHRVWeeklyPoint, StudyPointCompleteness>
    ) -> CGFloat {
        if point.weekIndex == selectedWeek { return 140 }
        return point[keyPath: completeness] == .sparse ? 32 : 48
    }

    private func selectWeek(
        at location: CGPoint,
        points: [DHSHRVWeeklyPoint],
        value: KeyPath<DHSHRVWeeklyPoint, Double?>,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        let plotFrame = geometry[proxy.plotAreaFrame]
        let xInPlot = location.x - plotFrame.origin.x
        let count = DHSHRVStudyResult.weeklyPointCount

        let week: Int
        if let raw = proxy.value(atX: xInPlot, as: Double.self) {
            week = Int(raw.rounded())
        } else if plotFrame.width > 0 {
            // Fallback: the x domain is fixed to 1...count with no padding.
            let fraction = max(0, min(1, xInPlot / plotFrame.width))
            week = Int((fraction * Double(count - 1)).rounded()) + 1
        } else {
            return
        }

        guard (1 ... count).contains(week) else { return }

        if selectedWeek == week {
            dismissPopup()
            return
        }

        // Anchor the popup at the tapped point, converted to the screen coordinate space.
        let overlayOrigin = geometry.frame(in: .named(studySpace)).origin
        let pointX = (proxy.position(forX: week) ?? xInPlot) + plotFrame.minX
        var pointY = plotFrame.minY
        if let point = points.first(where: { $0.weekIndex == week }),
           let y = point[keyPath: value],
           let positionY = proxy.position(forY: y) {
            pointY = positionY + plotFrame.minY
        }
        let anchor = CGPoint(x: pointX + overlayOrigin.x, y: pointY + overlayOrigin.y)

        withAnimation(.easeInOut(duration: 0.15)) {
            selectedWeek = week
            popupAnchor = anchor
        }
    }

    private func dismissPopup() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedWeek = nil
            popupAnchor = nil
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
    private func weekPopupLayer(_ result: DHSHRVStudyResult) -> some View {
        if let selectedWeek,
           let anchor = popupAnchor,
           let point = result.weeklyPoints.first(where: { $0.weekIndex == selectedWeek }) {
            ZStack {
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismissPopup() }

                GeometryReader { root in
                    let maxWidth: CGFloat = 250
                    let margin: CGFloat = 12
                    let arrowHeight: CGFloat = 8
                    let gap: CGFloat = 8
                    let halfWidth = popupSize.width / 2
                    let clampedX = min(
                        max(anchor.x, margin + halfWidth),
                        max(margin + halfWidth, root.size.width - margin - halfWidth)
                    )
                    let showAbove = anchor.y - popupSize.height - arrowHeight - gap > margin
                    let centerY = showAbove
                        ? anchor.y - gap - arrowHeight - popupSize.height / 2
                        : anchor.y + gap + arrowHeight + popupSize.height / 2
                    let pointerOffset = min(max(anchor.x - clampedX, -halfWidth + 16), halfWidth - 16)

                    weekPopupCard(point, pointerOffset: pointerOffset, arrowHeight: arrowHeight, showAbove: showAbove)
                        .frame(maxWidth: maxWidth)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(key: PopupSizeKey.self, value: proxy.size)
                            }
                        )
                        .position(x: clampedX, y: centerY)
                }
                .onPreferenceChange(PopupSizeKey.self) { popupSize = $0 }
            }
            .transition(.opacity)
        }
    }

    private func weekPopupCard(
        _ point: DHSHRVWeeklyPoint,
        pointerOffset: CGFloat,
        arrowHeight: CGFloat,
        showAbove: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Week \(point.weekIndex)")
                        .font(.subheadline.weight(.bold))
                    Text("\(formatRange(point.dhsStartDate, point.dhsEndDate)) DHS  •  \(formatRange(point.hrvStartDate, point.hrvEndDate)) HRV")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Button {
                    dismissPopup()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close week details")
            }

            HStack(spacing: 8) {
                weekMetric(
                    title: "DHS average",
                    valueText: point.averageDHS.map { ScoreCalculator.formatDisplayScore($0) } ?? "—",
                    detailText: "\(point.dhsValueCount) of 7 days",
                    completeness: point.dhsCompleteness,
                    accent: AppTheme.primary
                )
                weekMetric(
                    title: "Following-night HRV",
                    valueText: point.averageHRV.map { "\(Int($0.rounded())) ms" } ?? "—",
                    detailText: "\(point.hrvValueCount) of 7 nights",
                    completeness: point.hrvCompleteness,
                    accent: AppTheme.leaf
                )
            }
        }
        .padding(14)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .overlay(alignment: showAbove ? .bottom : .top) {
            PopupPointer(pointingDown: showAbove)
                .fill(AppTheme.cardSurface)
                .frame(width: 16, height: arrowHeight)
                .offset(x: pointerOffset, y: showAbove ? arrowHeight : -arrowHeight)
        }
        .cardShadow()
    }

    private func weekMetric(
        title: String,
        valueText: String,
        detailText: String,
        completeness: StudyPointCompleteness,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(valueText)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
            HStack(spacing: 5) {
                Circle()
                    .fill(completeness == .solid ? accent : accent.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text(completeness == .none ? "No data this week" : detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Normalized overlay

    private func overlayCard(_ result: DHSHRVStudyResult, isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Do They Rise and Fall Together?")
                .font(.headline.weight(.semibold))

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
                RuleMark(y: .value("Average", 0))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartForegroundStyleScale(["DHS": AppTheme.primary, "HRV": AppTheme.leaf])
            .chartYAxisLabel("Relative to average")
            .chartXAxis { weekAxisMarks }
            .frame(height: isLandscape ? 260 : 220)

            interpretationBlock(
                shows: "The same two trends rescaled so they share one axis. Above the dashed line is above your 91-day average; below it is below average.",
                matters: "DHS (0–10) and HRV (milliseconds) use different units, so on their own they are hard to compare. Putting them on one scale makes shared rises and dips obvious.",
                conclude: "When the two lines move up and down together, your healthier and less-healthy weeks are tracking your overnight HRV. Crossings and gaps show the weeks where they parted ways."
            )
        }
        .dhsCard()
    }

    // MARK: - Scatterplot

    private func scatterplotCard(_ result: DHSHRVStudyResult, isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Points Scatterplot")
                .font(.headline.weight(.semibold))

            Chart {
                if let fit = result.scatterFit {
                    LineMark(
                        x: .value("DHS", fit.xMin),
                        y: .value("HRV", fit.y(at: fit.xMin)),
                        series: .value("Series", "fit")
                    )
                    .foregroundStyle(AppTheme.leaf.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    LineMark(
                        x: .value("DHS", fit.xMax),
                        y: .value("HRV", fit.y(at: fit.xMax)),
                        series: .value("Series", "fit")
                    )
                    .foregroundStyle(AppTheme.leaf.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }

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

            interpretationBlock(
                shows: "Each dot is one 7-day block, placed by its DHS average (left–right) and HRV average (up–down). The dashed line is the best fit through those dots.",
                matters: "This is the most direct check of the hypothesis: it asks, week by week, whether higher DHS came with higher HRV — no smoothing or trend lines in between.",
                conclude: scatterConclusion(result)
            )
        }
        .dhsCard()
    }

    private func scatterConclusion(_ result: DHSHRVStudyResult) -> String {
        guard let fit = result.scatterFit else {
            return "Once a few more weeks have both DHS and HRV, the dots and best-fit line will show whether higher-DHS weeks were also higher-HRV weeks."
        }
        if fit.slope > 0 {
            return "The line tilts upward, so higher-DHS weeks tended to be higher-HRV weeks. Scatter around the line is normal — many things besides DHS move HRV."
        }
        if fit.slope < 0 {
            return "The line tilts downward in this window, so higher-DHS weeks did not come with higher HRV here. With 13 points this can shift as more data arrives."
        }
        return "The line is roughly flat, so DHS and HRV did not track each other clearly in this window."
    }

    // MARK: - Alignment over time

    private func alignmentOverTimeCard(_ result: DHSHRVStudyResult, isLandscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("DHS-HRV Alignment Over Time")
                    .font(.headline.weight(.semibold))
                Spacer(minLength: 0)
                if let stats = result.alignmentStats {
                    Label(stats.direction.label, systemImage: stats.direction.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(trendColor(stats.direction))
                }
            }

            Text("Is higher DHS linked to higher overnight HRV — and does that link hold up over time? This tracks the strength of that link, not your DHS or HRV scores themselves.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let stats = result.alignmentStats {
                alignmentMetricRow(stats)
            }

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
                if let median = result.alignmentStats?.median {
                    RuleMark(y: .value("Typical", median))
                        .foregroundStyle(AppTheme.primary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("typical")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                RuleMark(y: .value("No relationship", 0))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
            .chartForegroundStyleScale(["Spearman": AppTheme.primary, "Pearson": AppTheme.leaf])
            .chartYScale(domain: -1 ... 1)
            .chartYAxisLabel("Higher DHS ↔ higher HRV")
            .chartXAxisLabel("Older → Newer windows")
            .chartYAxis {
                AxisMarks(values: [-1, -0.5, 0, 0.5, 1]) { value in
                    AxisGridLine()
                    AxisTick()
                    if let number = value.as(Double.self) {
                        AxisValueLabel {
                            Text(number == 0 ? "0" : String(format: "%+.1f", number))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 6)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartPlotStyle { plotArea in
                plotArea.background(
                    LinearGradient(
                        colors: [
                            AppTheme.leaf.opacity(0.12),
                            Color.clear,
                            cautionColor.opacity(0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: isLandscape ? 260 : 220)

            alignmentScaleGuide()

            alignmentCallout(result)

            interpretationBlock(
                shows: "How strongly your higher-DHS weeks lined up with higher overnight HRV, recalculated across the last 30 windows (each shifted one day). The closer a line sits to +1, the more reliably higher DHS came with higher HRV.",
                matters: "One good 91-day window could be luck. Watching the line as the window slides day by day shows whether “higher DHS, higher HRV” is a stable feature of your data or just a passing coincidence.",
                conclude: "A line that holds high and positive across most windows is strong personal evidence that higher DHS is associated with higher overnight HRV for you. It shows association, not proof of cause, and neighboring windows share most of their data — so read the overall level, not single-day jumps."
            )
        }
        .dhsCard()
    }

    private func alignmentScaleGuide() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            scaleGuideRow(
                color: AppTheme.leaf,
                symbol: "arrow.up",
                text: "Near +1 — your higher-DHS weeks were followed by higher overnight HRV. This is what you want to see."
            )
            scaleGuideRow(
                color: .secondary,
                symbol: "minus",
                text: "Around 0 — little or no link between DHS and HRV in that window."
            )
            scaleGuideRow(
                color: cautionColor,
                symbol: "arrow.down",
                text: "Below 0 — higher-DHS weeks came with lower HRV (the opposite of the goal)."
            )
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func scaleGuideRow(color: Color, symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 16)
                .padding(.top, 1)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func alignmentMetricRow(_ stats: DHSHRVAlignmentStats) -> some View {
        HStack(alignment: .top, spacing: 10) {
            alignmentMetric(
                value: "\(stats.positiveCount)/\(stats.total)",
                label: "Windows higher DHS = higher HRV"
            )
            alignmentMetric(
                value: String(format: "%.2f", stats.median),
                label: "Typical link (\(stats.typicalLabel))"
            )
            alignmentMetric(
                value: "\(String(format: "%.2f", stats.minValue)) – \(String(format: "%.2f", stats.maxValue))",
                label: "Weakest – strongest"
            )
        }
    }

    private func alignmentMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppTheme.leaf.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func alignmentCallout(_ result: DHSHRVStudyResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("What this is telling you", systemImage: "heart.text.square.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(result.alignmentStrengthText)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
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

    private func trendColor(_ direction: DHSHRVTrendDirection) -> Color {
        switch direction {
        case .strengthening: return AppTheme.leaf
        case .steady: return .secondary
        case .easing: return cautionColor
        }
    }

    // MARK: - Methods

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

            Text("We use your latest 91 complete DHS days, pair each day with the sleep HRV from the night that followed it, then group those 91 pairs into 13 weekly points before measuring how closely they move together.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dhsCard()
    }

    // MARK: - Shared building blocks

    private func interpretationBlock(shows: String, matters: String, conclude: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            interpretationRow(label: "What it shows", text: shows, icon: "chart.xyaxis.line")
            interpretationRow(label: "Why it matters", text: matters, icon: "lightbulb.fill")
            interpretationRow(label: "What you can conclude", text: conclude, icon: "checkmark.seal.fill")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.primary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func interpretationRow(label: String, text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .frame(width: 16)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.primary)
                Text(text)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func healthTieIn(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.leaf)
                .padding(.top, 1)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.leaf.opacity(0.10))
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
        case "negative": return cautionColor
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

Each DHS day is paired with the sleep HRV from the night that followed it (DHS[t] with HRV[t+1]).

Those 91 pairs are grouped into 13 non-overlapping 7-day blocks. Each point on the chart is one block's average.

Spearman correlation (primary) asks whether higher-DHS weeks generally rank with higher-HRV weeks. It cares about order, so one unusual week does not distort it.

Pearson correlation (secondary) asks whether the weekly points fall along a straight line. It uses the exact values, so a single outlier week can move it more.

Both run from −1 (move in opposite directions) through 0 (no relationship) to +1 (move together perfectly).

How sure can you be? With only 13 weekly points, a single correlation has a wide margin of error. We translate that margin into a plain-language range using a standard Fisher transformation, so you can see whether the relationship is likely weak, moderate, or strong rather than trusting one number.

DHS-HRV Alignment Over Time repeats the entire calculation across the last 30 windows, each shifted one day. Because neighboring windows share almost all of their days, the value moves smoothly — so read the overall level and drift, not single-day jumps. A relationship that stays positive across many windows is stronger evidence than one good window alone.

This is an exploratory view of your own data. It can reveal associations in your habits and recovery, but it cannot prove that one causes the other.
"""
    }
}

private struct PopupSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

/// A small triangle pointer that visually connects the popup to its data point.
private struct PopupPointer: Shape {
    var pointingDown: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if pointingDown {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        } else {
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        path.closeSubpath()
        return path
    }
}
