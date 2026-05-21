import SwiftUI

/// Today is a single-screen dashboard — never scrolls. Everything the user
/// needs to see for the current day fits inside the safe area:
/// brand-gradient hero card with date and animated score ring, a row of
/// three metric cards, and a primary-focus suggestion card. Secondary
/// actions (refresh, support messages) live in the navigation bar.
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
                content
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Daily Health Score")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
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

    // MARK: - Body content

    @ViewBuilder
    private var content: some View {
        if let record = displayRecord {
            VStack(spacing: 14) {
                if appState.isSyncingHealth {
                    syncingBanner
                }
                if let error = appState.lastSyncError {
                    errorBanner(error)
                }

                heroCard(for: record)

                metricRow(for: record)

                focusCard(for: record)

                Spacer(minLength: 0)
            }
        } else {
            emptyState
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Image("BrandMark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                discText = appState.settingsStore.nextDiscouragement()
                withAnimation { showDiscouragement = true }
            } label: {
                Image(systemName: "heart.text.square")
            }
            .accessibilityLabel("Feeling discouraged")

            Button {
                motivText = appState.settingsStore.nextMotivation()
                withAnimation { showMotivation = true }
            } label: {
                Image(systemName: "sparkles")
            }
            .accessibilityLabel("Need motivation")

            Button {
                Task { await appState.syncTodayFromHealth() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Refresh from Apple Health")
        }
    }

    // MARK: - Hero card (logo + date + score ring)

    private func heroCard(for record: DailyRecord) -> some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image("BrandMark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(.white.opacity(0.10), lineWidth: 0.5)
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text("Today")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .textCase(.uppercase)
                        .tracking(1)
                    Text(DateHelpers.formatDisplayDate(record.date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                if record.date != todayKey {
                    Text("No data for today")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            ScoreRingView(score: record.totalScore, lineWidth: 12, size: 140)

            Text(focusHeadline(for: record))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
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
        HStack(spacing: 10) {
            CompactMetricCard(
                title: "Sleep",
                value: "\(ScoreCalculator.formatDisplayScore(record.sleepHours))",
                unit: "hr",
                scoreText: "\(ScoreCalculator.formatDisplayScore(record.sleepScore)) / 4",
                fractionOfGoal: record.sleepHours / record.sleepGoal.rawValue,
                systemImage: "moon.stars.fill",
                tint: AppTheme.primary
            )
            CompactMetricCard(
                title: "Fiber",
                value: "\(ScoreCalculator.formatDisplayScore(record.fiberGrams))",
                unit: "g",
                scoreText: "\(ScoreCalculator.formatDisplayScore(record.fiberScore)) / 4",
                fractionOfGoal: record.fiberGrams / Double(record.fiberGoal.rawValue),
                systemImage: "leaf.fill",
                tint: AppTheme.leaf
            )
            CompactMetricCard(
                title: "Exercise",
                value: "\(Int(record.exerciseMinutes.rounded()))",
                unit: "min",
                scoreText: "\(ScoreCalculator.formatDisplayScore(record.exerciseScore)) / 2",
                fractionOfGoal: record.exerciseMinutes / Double(record.exerciseGoalMinutes),
                systemImage: "figure.run",
                tint: AppTheme.tint(for: .exercise)
            )
        }
    }

    // MARK: - Primary focus / suggestion

    private func focusCard(for record: DailyRecord) -> some View {
        let tint = AppTheme.tint(for: record.primaryFocus)
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: AppTheme.symbol(for: record.primaryFocus))
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 4) {
                Text("PRIMARY FOCUS · \(ScoreCalculator.primaryFocusLabel(record.primaryFocus).uppercased())")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
                Text(record.suggestion)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .dhsCard(padding: 14)
    }

    // MARK: - Banners

    private var syncingBanner: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text("Syncing from Apple Health…")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

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
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

// MARK: - Compact metric card (one of three in the Today row)

private struct CompactMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let scoreText: String
    let fractionOfGoal: Double
    let systemImage: String
    let tint: Color

    private var capped: Double { max(0, min(fractionOfGoal, 1)) }
    private var atOrOverGoal: Bool { fractionOfGoal >= 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(tint.opacity(0.15)))
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                if atOrOverGoal {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.leaf)
                        .accessibilityLabel("Goal met")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.15))
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * capped)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: capped)
                }
            }
            .frame(height: 5)

            Text(scoreText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit), \(scoreText)")
    }
}
