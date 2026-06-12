import SwiftUI

/// Today dashboard: hero score, metric row, focus suggestion, SMART Goals,
/// and HRV. Scrolls when content exceeds the safe area. Secondary actions
/// (refresh, support messages) live in the navigation bar.
struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    @State private var showDiscouragement = false
    @State private var showMotivation = false
    @State private var showHRVTrendsInfo = false
    @State private var discText: String = ""
    @State private var motivText: String = ""
    /// Shared 0…1 progress for coordinated dial-up (ring, numbers, bars).
    @State private var dialUpProgress: Double = 0
    @State private var hasPlayedLaunchDialUp = false
    @State private var dialUpTask: Task<Void, Never>?

    private var todayKey: String { DateHelpers.localDateKey() }

    /// Only ever the actual current day. We never fall back to an older record,
    /// which previously rendered yesterday under a "TODAY" header.
    private var displayRecord: DailyRecord? {
        appState.recordStore.records.first { $0.date == todayKey }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()
                content
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                TodayTopBar(
                    onDiscouragement: {
                        discText = appState.settingsStore.nextDiscouragement()
                        withAnimation { showDiscouragement = true }
                    },
                    onMotivation: {
                        motivText = appState.settingsStore.nextMotivation()
                        withAnimation { showMotivation = true }
                    },
                    onRefresh: {
                        Task { await appState.syncTodayFromHealth(userInitiated: true) }
                    }
                )
            }
        }
        .task { await playLaunchDialUpIfNeeded() }
        .onAppear { appState.refreshTodaySuggestionForDisplayIfNeeded() }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            appState.refreshTodaySuggestionForDisplayIfNeeded()
        }
        .onChange(of: displayRecord?.date) { oldDate, newDate in
            guard oldDate == nil, newDate != nil else { return }
            Task { await playLaunchDialUpIfNeeded() }
        }
        .onChange(of: appState.userRefreshToken) { _, _ in
            startDialUp()
        }
        .onDisappear { dialUpTask?.cancel() }
        .paragraphDialog(
            isPresented: $showDiscouragement,
            title: "Feeling discouraged?",
            text: discText
        )
        .paragraphDialog(
            isPresented: $showMotivation,
            title: "Need motivation?",
            text: motivText
        )
        .infoScrollDialog(
            isPresented: $showHRVTrendsInfo,
            title: HRVEducationLibrary.title,
            text: HRVEducationLibrary.body
        )
    }

    private var hrvSummary: HRVRollingSummary {
        HRVRollingCalculator.compute(
            records: appState.recordStore.records,
            todayKey: todayKey
        )
    }

    // MARK: - Body content

    @ViewBuilder
    private var content: some View {
        if let record = displayRecord {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    if let error = appState.lastSyncError {
                        errorBanner(error)
                    }

                    heroCard(for: record)

                    metricRow(for: record)
                        .animation(DialUpAnimation.timing, value: dialUpProgress)

                    focusCard(for: record)

                    TodaySMARTGoalsCard(
                        attentionCount: SMARTGoalLogic.attentionCount(
                            goals: appState.smartGoalStore.goals
                        )
                    )

                    NavigationLink {
                        HRVGraphView(
                            records: appState.recordStore.records,
                            todayKey: todayKey
                        )
                    } label: {
                        TodayHRVCard(summary: hrvSummary) {
                            withAnimation { showHRVTrendsInfo = true }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)
            }
        } else if hasAnyRecords || appState.isSyncingHealth {
            // Returning user (or first sync in flight): build today's record before
            // showing anything, rather than flashing stale data or the connect prompt.
            preparingTodayState
        } else {
            emptyState
        }
    }

    private var hasAnyRecords: Bool {
        !appState.recordStore.records.isEmpty
    }

    // MARK: - Dial-up

    private func playLaunchDialUpIfNeeded() async {
        guard displayRecord != nil, !hasPlayedLaunchDialUp else { return }
        hasPlayedLaunchDialUp = true
        try? await Task.sleep(nanoseconds: 50_000_000)
        startDialUp()
    }

    private func startDialUp() {
        guard displayRecord != nil else { return }
        dialUpTask?.cancel()
        dialUpTask = Task { @MainActor in
            await DialUpAnimation.animate { dialUpProgress = $0 }
        }
    }

    // MARK: - Hero card (date + score ring)

    private func heroCard(for record: DailyRecord) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Today")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .textCase(.uppercase)
                        .tracking(1)
                    Text(DateHelpers.formatDisplayDate(record.date))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }

            ScoreRingView(
                score: record.totalScore,
                animationProgress: dialUpProgress,
                lineWidth: 10,
                size: 118
            )

            Text(focusHeadline(for: record))
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            AppTheme.heroGradient
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.heroCornerRadius, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Layout.heroCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: AppTheme.backgroundDeep.opacity(0.25), radius: 14, x: 0, y: 6)
    }

    private func focusHeadline(for record: DailyRecord) -> String {
        switch record.primaryFocus {
        case .maintain: return "All goals met — stay the course."
        case .sleep:    return "Tonight's focus: sleep."
        case .fiber:    return "Today's focus: fiber."
        case .exercise: return "Today's focus: movement."
        }
    }

    // MARK: - Three compact metric cards in a single row

    private func metricRow(for record: DailyRecord) -> some View {
        HStack(spacing: 8) {
            CompactMetricCard(
                title: "Sleep",
                metricValue: record.sleepHours,
                unitSuffix: "hr",
                usesIntegerDisplay: false,
                scoreValue: record.sleepScore,
                maxScore: 4,
                goalValue: record.sleepGoal.rawValue,
                animationProgress: dialUpProgress,
                systemImage: "moon.stars.fill",
                tint: AppTheme.primary
            )
            CompactMetricCard(
                title: "Fiber",
                metricValue: record.fiberGrams,
                unitSuffix: "g",
                usesIntegerDisplay: false,
                scoreValue: record.fiberScore,
                maxScore: 4,
                goalValue: Double(record.fiberGoal.rawValue),
                animationProgress: dialUpProgress,
                systemImage: "leaf.fill",
                tint: AppTheme.leaf
            )
            CompactMetricCard(
                title: "Exercise",
                metricValue: record.exerciseMinutes,
                unitSuffix: "min",
                usesIntegerDisplay: true,
                scoreValue: record.exerciseScore,
                maxScore: 2,
                goalValue: Double(record.exerciseGoalMinutes),
                animationProgress: dialUpProgress,
                systemImage: "figure.run",
                tint: AppTheme.tint(for: PrimaryFocus.exercise)
            )
        }
    }

    // MARK: - Primary focus / suggestion

    private func focusCard(for record: DailyRecord) -> some View {
        let tint = AppTheme.tint(for: record.primaryFocus)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: AppTheme.symbol(for: record.primaryFocus))
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 3) {
                Text("PRIMARY FOCUS · \(ScoreCalculator.primaryFocusLabel(record.primaryFocus).uppercased())")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                Text(record.suggestion)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .dhsCard(padding: 10)
    }

    // MARK: - Banners

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error)
                .font(.footnote)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Empty state (single-screen, no scroll)

    private var preparingTodayState: some View {
        VStack(spacing: 16) {
            Spacer()
            if let error = appState.lastSyncError {
                errorBanner(error)
                    .padding(.horizontal, 8)
            }
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image("BrandMark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 110, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: AppTheme.backgroundDeep.opacity(0.25), radius: 12, x: 0, y: 6)
            VStack(spacing: 6) {
                Text("Daily Health Score")
                    .font(.title3.weight(.semibold))
                Text("Allow Apple Health access to see today's sleep, fiber, and exercise.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            TodaySMARTGoalsCard(
                attentionCount: SMARTGoalLogic.attentionCount(
                    goals: appState.smartGoalStore.goals
                )
            )
            .padding(.horizontal, 8)

            Button {
                Task {
                    await appState.requestHealthAccess()
                    await appState.syncTodayFromHealth(userInitiated: true)
                }
            } label: {
                Text("Connect Apple Health")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

// MARK: - Compact metric card (one of three in the Today row)

private struct CompactMetricCard: View {
    let title: String
    let metricValue: Double
    let unitSuffix: String
    let usesIntegerDisplay: Bool
    let scoreValue: Double
    let maxScore: Double
    let goalValue: Double
    let animationProgress: Double
    let systemImage: String
    let tint: Color

    private var progress: Double { max(0, min(animationProgress, 1)) }

    private var displayedMetric: Double { metricValue * progress }
    private var displayedScore: Double { scoreValue * progress }

    private var fractionOfGoal: Double {
        guard goalValue > 0 else { return 0 }
        return metricValue / goalValue
    }

    private var animatedBarFraction: Double {
        max(0, min(fractionOfGoal * progress, 1))
    }

    private var atOrOverGoal: Bool { fractionOfGoal >= 1 }

    private var metricDisplayText: String {
        if usesIntegerDisplay {
            return "\(Int(displayedMetric.rounded()))"
        }
        return ScoreCalculator.formatDisplayScore(displayedMetric)
    }

    private var scoreDisplayText: String {
        "\(ScoreCalculator.formatDisplayScore(displayedScore)) / \(ScoreCalculator.formatDisplayScore(maxScore))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(tint.opacity(0.15)))
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(metricDisplayText)
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: displayedMetric))
                Text(unitSuffix)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * animatedBarFraction)
                }
            }
            .frame(height: 4)

            HStack(alignment: .center, spacing: 4) {
                Text(scoreDisplayText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: displayedScore))
                Spacer(minLength: 0)
                if atOrOverGoal, progress >= 1 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.leaf)
                        .accessibilityLabel("Goal met")
                }
            }
        }
        .animation(DialUpAnimation.timing, value: animationProgress)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(metricDisplayText) \(unitSuffix), \(scoreDisplayText)")
    }
}
