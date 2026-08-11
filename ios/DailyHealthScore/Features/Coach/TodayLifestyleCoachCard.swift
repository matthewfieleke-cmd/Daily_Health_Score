import SwiftUI

/// Richer Today card: acknowledgment, why it matters, next step — or setup/status.
struct TodayLifestyleCoachCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController

    let record: DailyRecord?
    var onAskCoach: (() -> Void)?

    /// Part of the refresh identity: a card written this morning should be
    /// rewritten once the evening starts, not left sitting there all day.
    private var phase: DayPhase { .current() }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if coach.availability != .available {
                statusBody
            } else if coach.isGeneratingDailyCard && coach.dailyCard == nil {
                loadingBody
            } else if let card = coach.dailyCard {
                cardBody(card)
                askCoachButton
            } else if let error = coach.dailyCardError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                askCoachButton
            } else {
                statusBody
            }
        }
        .dhsCard(padding: 14)
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
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("DHS Lifestyle Coach")
                    .font(.subheadline.weight(.semibold))
                Text(CoachCharter.philosophy)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    private var statusBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(coach.availability.title)
                .font(.footnote.weight(.semibold))
            Text(coach.availability.guidance)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var loadingBody: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Preparing today’s coaching note…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func cardBody(_ card: DailyCoachCardContent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            coachSection(title: "With you", text: card.acknowledgment)
            coachSection(title: "Why it matters", text: card.whyItMatters)
            // The next step is the only part that asks anything of the reader,
            // so it gets the visual weight rather than sitting third in a stack
            // of three identical paragraphs.
            nextStepSection(card.nextStep)
        }
    }

    private func coachSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nextStepSection(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "arrow.forward.circle.fill")
                .font(.footnote)
                .foregroundStyle(AppTheme.leaf)
                .padding(.top, 1)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("NEXT STEP")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.leaf)
                    .tracking(0.5)
                Text(text)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.leaf.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
