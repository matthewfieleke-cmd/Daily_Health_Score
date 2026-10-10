import SwiftUI

/// Today dashboard: hero score, metric row, and DHS Lifestyle Coach. SMART
/// goals, HRV analysis, the coach, and refresh are all reached from the top
/// bar. The dashboard itself is a single screen — it never scrolls. Extra
/// coaching depth lives in the chat sheet.
struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    @State private var coachLaunch: CoachChatLaunch?
    @State private var trendMetric: TrendMetric?
    @State private var healthChart: CoachHealthMeasure?
    @State private var showFoodLog = false
    @State private var chatAfterChart: CoachChatLaunch?
    @State private var showIntake = false
    @State private var showSMARTGoals = false
    @State private var showHRVAnalysis = false
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
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showSMARTGoals) {
                SMARTGoalsListView()
            }
            .navigationDestination(isPresented: $showHRVAnalysis) {
                DHSHRVStudyView(
                    records: appState.recordStore.records,
                    todayKey: todayKey
                )
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                TodayTopBar(
                    smartGoalAttentionCount: SMARTGoalLogic.attentionCount(
                        goals: appState.smartGoalStore.goals
                    ),
                    onAskCoach: { coachLaunch = .chats },
                    onOpenSMARTGoals: { showSMARTGoals = true },
                    onOpenHRVAnalysis: { showHRVAnalysis = true },
                    onRefresh: {
                        Task { await appState.syncTodayFromHealth(userInitiated: true) }
                    }
                )
            }
        }
        .task { await playLaunchDialUpIfNeeded() }
        .onAppear {
            appState.coach.refreshAvailability()
            appState.refreshTodaySuggestionForDisplayIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            appState.coach.refreshAvailability()
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
        .sheet(isPresented: $showIntake) {
            NavigationStack {
                CoachIntakeView()
                    .environmentObject(appState)
                    .environmentObject(appState.coach)
            }
        }
        .sheet(item: $coachLaunch) { launch in
            NavigationStack {
                if launch == .chats {
                    CoachChatsView()
                        .environmentObject(appState)
                        .environmentObject(appState.coach)
                } else {
                    LifestyleCoachChatView(launch: launch)
                        .environmentObject(appState)
                        .environmentObject(appState.coach)
                }
            }
        }
        .sheet(isPresented: $showFoodLog) {
            FoodGroupLogSheet(dateKey: todayKey)
                .environmentObject(appState)
        }
        .sheet(item: $healthChart) { measure in
            NavigationStack {
                HealthChartScreen(measure: measure)
            }
        }
        .sheet(item: $trendMetric, onDismiss: openChatAfterChart) { metric in
            NavigationStack {
                TrendChartScreen(
                    records: appState.recordStore.records,
                    settings: appState.settingsStore.settings,
                    metric: metric,
                    showsTalk: true,
                    onTalk: {
                        chatAfterChart = appState.coach.memory.cachedCheckIn?.replyThreadID.map {
                            CoachChatLaunch.thread($0)
                        } ?? .replyToCheckIn
                        trendMetric = nil
                    }
                )
            }
        }
    }

    // MARK: - Body content

    @ViewBuilder
    private var content: some View {
        if let record = displayRecord {
            VStack(spacing: 12) {
                if let error = appState.lastSyncError {
                    errorBanner(error)
                }

                heroCard(for: record)

                metricRow(for: record)
                    .animation(DialUpAnimation.timing, value: dialUpProgress)

                TodayCoachCheckInCard(
                    record: record,
                    onReply: { coachLaunch = .replyToCheckIn },
                    onContinueReply: { coachLaunch = .thread($0) },
                    onIntake: { showIntake = true },
                    onShowChart: { trendMetric = $0 },
                    onShowHealthChart: { healthChart = $0 }
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    // Remaining height is the grouped screen, not empty card chrome.
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .textCase(.uppercase)
                    .tracking(1.2)
                Text(DateHelpers.formatHeroWeekday(record.date))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(DateHelpers.formatHeroMonthDay(record.date))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ScoreRingView(
                score: record.totalScore,
                animationProgress: dialUpProgress,
                lineWidth: 8,
                size: AppTheme.Layout.todayHeroRingSize,
                onDarkBackground: true
            )
        }
        .padding(.horizontal, 16)
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
        .shadow(color: AppTheme.backgroundDeep.opacity(0.22), radius: 12, x: 0, y: 5)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Three compact metric cards in a single row

    private var nutritionMode: NutritionMode {
        appState.settingsStore.settings.nutritionMode
    }

    private func metricRow(for record: DailyRecord) -> some View {
        let foodGlance = nutritionMode == .foodGroups ? FoodGroupScore.glance(record.foodGroups) : nil
        return HStack(alignment: .top, spacing: 8) {
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
                tint: AppTheme.primary,
                accessibilityHint: "Asks the coach about today's sleep",
                onTap: { askCoach(about: .sleep, record: record) }
            )
            .contextMenu {
                Button("Ask Coach about this") { askCoach(about: .sleep, record: record) }
            }
            CompactMetricCard(
                title: nutritionMode.cardTitle,
                metricValue: nutritionMode == .foodGroups ? record.fiberScore : record.fiberGrams,
                unitSuffix: nutritionMode == .foodGroups ? "pts" : "g",
                usesIntegerDisplay: false,
                scoreValue: record.fiberScore,
                maxScore: 4,
                goalValue: nutritionMode == .foodGroups ? 4 : UserSettings.fiberGoalGrams,
                animationProgress: dialUpProgress,
                systemImage: foodGroupsSymbol(isLogged: foodGlance?.isLogged),
                tint: AppTheme.leaf,
                valueText: foodGlance?.isLogged == false ? foodGlance?.headline : nil,
                detailText: foodGlance?.detail,
                emphasizeValue: foodGlance?.isLogged == false,
                accessibilitySummary: foodGlance?.spoken,
                accessibilityHint: nutritionMode == .foodGroups
                    ? "Opens today's food log"
                    : "Asks the coach about today's fiber",
                onTap: {
                    if nutritionMode == .foodGroups {
                        showFoodLog = true
                    } else {
                        askCoach(about: .fiber, record: record)
                    }
                }
            )
            .contextMenu {
                Button("Ask Coach about this") { askCoach(about: .fiber, record: record) }
            }
            CompactMetricCard(
                title: record.movementGoal.metricName,
                metricValue: record.movementValue,
                unitSuffix: record.movementGoal.unit,
                usesIntegerDisplay: true,
                scoreValue: record.exerciseScore,
                maxScore: 2,
                goalValue: record.movementGoal.goalValue,
                animationProgress: dialUpProgress,
                systemImage: record.movementGoal.systemImage,
                tint: AppTheme.tint(for: PrimaryFocus.exercise),
                accessibilityHint: "Asks the coach about today's \(record.movementGoal.metricName.lowercased())",
                onTap: { askCoach(about: .exercise, record: record) }
            )
            .contextMenu {
                Button("Ask Coach about this") { askCoach(about: .exercise, record: record) }
            }
        }
    }

    private func foodGroupsSymbol(isLogged: Bool?) -> String {
        guard nutritionMode == .foodGroups else { return "leaf.fill" }
        return isLogged == true ? "fork.knife" : "plus.circle.fill"
    }

    private func openChatAfterChart() {
        guard let chatAfterChart else { return }
        let launch = chatAfterChart
        self.chatAfterChart = nil
        coachLaunch = launch
    }

    /// A metric tap starts a new chat that opens on that metric's numbers.
    private func askCoach(about feature: CoachFocusFeature, record: DailyRecord) {
        coachLaunch = .focus(
            CoachFocusContextBuilder.metric(
                feature,
                record: record,
                nutritionMode: nutritionMode
            )
        )
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
    /// Replaces the dialing number. Used when the day has no food-group log.
    var valueText: String? = nil
    /// Replaces the "points / max" line. Food groups name the open group instead.
    var detailText: String? = nil
    var emphasizeValue: Bool = false
    var accessibilitySummary: String? = nil
    var accessibilityHint: String? = nil
    var onTap: (() -> Void)? = nil

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
            return MovementGoal.formatCount(displayedMetric)
        }
        return ScoreCalculator.formatDisplayScore(displayedMetric)
    }

    private var scoreDisplayText: String {
        "\(ScoreCalculator.formatDisplayScore(displayedScore)) / \(ScoreCalculator.formatDisplayScore(maxScore))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(tint.opacity(0.15)))
                // Two lines are reserved on every card. "Steps" is one line and
                // "Exercise Minutes" is two; the row must not change height.
                ZStack(alignment: .topLeading) {
                    Text("Exercise\nMinutes")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(2)
                        .hidden()
                        .accessibilityHidden(true)
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if let valueText {
                    Text(valueText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(emphasizeValue ? tint : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    Text(metricDisplayText)
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText(value: displayedMetric))
                }
                if valueText == nil, !unitSuffix.isEmpty {
                    Text(unitSuffix)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * animatedBarFraction)
                }
            }
            .frame(height: 4)

            HStack(alignment: .center, spacing: 4) {
                Text(detailText ?? scoreDisplayText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(detailText == nil ? .numericText(value: displayedScore) : .identity)
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
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAction(.default) { onTap?() }
    }

    private var accessibilityLabelText: String {
        let base: String
        if let accessibilitySummary {
            base = "\(title): \(accessibilitySummary)"
        } else if unitSuffix.isEmpty {
            base = "\(title): \(metricDisplayText), \(scoreDisplayText)"
        } else {
            base = "\(title): \(metricDisplayText) \(unitSuffix), \(scoreDisplayText)"
        }
        if atOrOverGoal, progress >= 1 {
            return "\(base), goal met"
        }
        return base
    }
}
