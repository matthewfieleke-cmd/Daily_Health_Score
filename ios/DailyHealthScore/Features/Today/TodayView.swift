import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appState: AppState

    @State private var showDiscouragement = false
    @State private var showMotivation = false
    @State private var discText: String = ""
    @State private var motivText: String = ""

    private var todayKey: String { DateHelpers.localDateKey() }

    private var displayRecord: DailyRecord? {
        let records = appState.recordStore.records
        return records.first { $0.date == todayKey } ?? records.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.Layout.sectionSpacing) {
                        if appState.isSyncingHealth {
                            syncingBanner
                        }

                        if let error = appState.lastSyncError {
                            errorBanner(error)
                        }

                        if let record = displayRecord {
                            heroCard(for: record)

                            if record.date != todayKey {
                                Text("Showing \(DateHelpers.formatDisplayDate(record.date)) — no Apple Health data for today yet.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            }

                            metricGrid(for: record)
                            focusCard(for: record)
                            supportButtons
                            refreshButton
                        } else {
                            emptyState
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await appState.syncTodayFromHealth()
                }
            }
            .navigationTitle("Daily Health Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image("BrandMark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .accessibilityHidden(true)
                }
            }
        }
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
    }

    // MARK: - Hero (brand background + score ring)

    private func heroCard(for record: DailyRecord) -> some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                Image("BrandMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .textCase(.uppercase)
                        .tracking(1)
                    Text(DateHelpers.formatDisplayDate(record.date))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }

            ScoreRingView(score: record.totalScore)
                .padding(.vertical, 6)

            Text(focusHeadline(for: record))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 22)
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

    // MARK: - Metric grid

    private func metricGrid(for record: DailyRecord) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            MetricCardView(
                title: "Sleep",
                valueText: "\(ScoreCalculator.formatDisplayScore(record.sleepHours)) hr",
                scoreText: ScoreCalculator.formatDisplayScore(record.sleepScore),
                maxScoreText: "4",
                fractionOfGoal: record.sleepHours / record.sleepGoal.rawValue,
                systemImage: "moon.stars.fill",
                tint: AppTheme.primary
            )
            MetricCardView(
                title: "Fiber",
                valueText: "\(ScoreCalculator.formatDisplayScore(record.fiberGrams)) g",
                scoreText: ScoreCalculator.formatDisplayScore(record.fiberScore),
                maxScoreText: "4",
                fractionOfGoal: record.fiberGrams / Double(record.fiberGoal.rawValue),
                systemImage: "leaf.fill",
                tint: AppTheme.leaf
            )
            MetricCardView(
                title: "Exercise",
                valueText: "\(Int(record.exerciseMinutes.rounded())) min",
                scoreText: ScoreCalculator.formatDisplayScore(record.exerciseScore),
                maxScoreText: "2",
                fractionOfGoal: record.exerciseMinutes / Double(record.exerciseGoalMinutes),
                systemImage: "figure.run",
                tint: AppTheme.tint(for: .exercise)
            )
        }
    }

    // MARK: - Primary focus & suggestion

    private func focusCard(for record: DailyRecord) -> some View {
        let tint = AppTheme.tint(for: record.primaryFocus)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: AppTheme.symbol(for: record.primaryFocus))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(tint.opacity(0.15)))
                VStack(alignment: .leading, spacing: 0) {
                    Text("PRIMARY FOCUS")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                    Text(ScoreCalculator.primaryFocusLabel(record.primaryFocus))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            Text(record.suggestion)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dhsCard()
    }

    // MARK: - Discouragement / Motivation buttons

    private var supportButtons: some View {
        HStack(spacing: 12) {
            Button {
                discText = appState.settingsStore.nextDiscouragement()
                withAnimation { showDiscouragement = true }
            } label: {
                supportLabel(systemImage: "heart.text.square", title: "Feeling\ndiscouraged?")
            }
            .buttonStyle(.plain)

            Button {
                motivText = appState.settingsStore.nextMotivation()
                withAnimation { showMotivation = true }
            } label: {
                supportLabel(systemImage: "sparkles", title: "Need\nmotivation?")
            }
            .buttonStyle(.plain)
        }
    }

    private func supportLabel(systemImage: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.callout)
                .foregroundStyle(AppTheme.primary)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
    }

    // MARK: - Refresh

    private var refreshButton: some View {
        Button {
            Task { await appState.syncTodayFromHealth() }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                Text("Refresh from Apple Health")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppTheme.primary)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Banners

    private var syncingBanner: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Syncing from Apple Health…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func errorBanner(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error)
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image("BrandMark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: AppTheme.backgroundDeep.opacity(0.25), radius: 12, x: 0, y: 6)
            VStack(spacing: 6) {
                Text("No data yet")
                    .font(.title3.weight(.semibold))
                Text("Allow Apple Health access, then tap Refresh to pull today's sleep, fiber, and exercise.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task {
                    await appState.requestHealthAccess()
                    await appState.syncTodayFromHealth()
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
        }
        .padding(.top, 40)
        .padding(.horizontal, 16)
    }
}
