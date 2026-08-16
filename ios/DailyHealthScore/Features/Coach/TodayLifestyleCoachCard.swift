import SwiftUI

/// Today card: a height-bounded teaser. Acknowledgment and why-it-matters
/// truncate; the next step keeps the visual weight; full depth belongs in
/// the chat sheet so Home never scrolls — including when PCC writes more.
struct TodayLifestyleCoachCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController

    let record: DailyRecord?
    var onAskCoach: (() -> Void)?

    /// Part of the refresh identity: a card written this morning should be
    /// rewritten once the evening starts, not left sitting there all day.
    private var phase: DayPhase { .current() }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Group {
                if coach.availability != .available {
                    statusBody
                    fallbackBody
                    Spacer(minLength: 6)
                    askCoachButton
                } else if coach.isGeneratingDailyCard && coach.dailyCard == nil {
                    loadingBody
                    Spacer(minLength: 0)
                    askCoachButton
                } else if let card = coach.dailyCard {
                    cardBody(card)
                } else {
                    fallbackBody
                    Spacer(minLength: 6)
                    askCoachButton
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
        .task(id: "\(record?.date ?? "")#\(phase.rawValue)") {
            guard let record else { return }
            await coach.ensureDailyCard(
                for: record,
                records: appState.recordStore.records,
                goals: appState.smartGoalStore.goals,
                hrvSensitivity: appState.settingsStore.hrvSensitivity
            )
        }
        .onChange(of: appState.userRefreshToken) { _, _ in
            guard let record else { return }
            Task {
                await coach.ensureDailyCard(
                    for: record,
                    records: appState.recordStore.records,
                    goals: appState.smartGoalStore.goals,
                    hrvSensitivity: appState.settingsStore.hrvSensitivity,
                    force: true
                )
            }
        }
    }

    @ViewBuilder
    private var askCoachButton: some View {
        if let onAskCoach {
            Button(action: onAskCoach) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                        .font(.caption)
                    Text("Talk this through")
                        .font(.footnote.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(AppTheme.primary)
                .padding(.vertical, 9)
                .padding(.horizontal, 11)
                .frame(maxWidth: .infinity)
                .background(AppTheme.primary.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image("DHSLifestyleCoach")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            Text("DHS Lifestyle Coach")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private var statusBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(coach.availability.title)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            Text(coach.availability.guidance)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var loadingBody: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Preparing today’s coaching note…")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func cardBody(_ card: DailyCoachCardContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .vertical) {
                VStack(alignment: .leading, spacing: 8) {
                    coachSection(title: "With you", text: card.acknowledgment, lineLimit: 2)
                    coachSection(title: "Why it matters", text: card.whyItMatters, lineLimit: 2)
                }
                VStack(alignment: .leading, spacing: 8) {
                    coachSection(title: "With you", text: card.acknowledgment, lineLimit: 2)
                    coachSection(title: "Why it matters", text: card.whyItMatters, lineLimit: 1)
                }
                coachSection(title: "With you", text: card.acknowledgment, lineLimit: 2)
                coachSection(title: "With you", text: card.acknowledgment, lineLimit: 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 6)
            nextStepSection(card.nextStep)
                .layoutPriority(1)
            askCoachButton
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func coachSection(title: String, text: String, lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
                .truncationMode(.tail)
                .accessibilityLabel(text)
        }
    }

    /// Shown when the model has nothing for us: no Apple Intelligence, or a
    /// generation that failed. A raw framework error is not useful to read.
    @ViewBuilder
    private var fallbackBody: some View {
        let suggestion = record?.suggestion.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !suggestion.isEmpty {
            nextStepSection(suggestion, title: "Today's focus")
        }
    }

    private func nextStepSection(_ text: String, title: String = "Next step", lineLimit: Int = 3) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "arrow.forward.circle.fill")
                .font(.footnote)
                .foregroundStyle(AppTheme.leaf)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.leaf)
                    .tracking(0.5)
                Text(text)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(lineLimit)
                    .truncationMode(.tail)
                    .accessibilityLabel(text)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.leaf.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
