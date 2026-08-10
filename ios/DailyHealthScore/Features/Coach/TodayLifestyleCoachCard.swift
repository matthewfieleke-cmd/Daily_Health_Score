import SwiftUI

/// Richer Today card: acknowledgment, why it matters, next step — or setup/status.
struct TodayLifestyleCoachCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController

    let record: DailyRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if coach.availability != .available {
                statusBody
            } else if coach.isGeneratingDailyCard && coach.dailyCard == nil {
                loadingBody
            } else if let card = coach.dailyCard {
                cardBody(card)
            } else if let error = coach.dailyCardError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                statusBody
            }
        }
        .dhsCard(padding: 14)
        .task(id: record?.date) {
            guard let record else { return }
            await coach.ensureDailyCard(
                for: record,
                records: appState.recordStore.records
            )
        }
        .onChange(of: appState.userRefreshToken) { _, _ in
            guard let record else { return }
            Task {
                await coach.ensureDailyCard(
                    for: record,
                    records: appState.recordStore.records,
                    force: true
                )
            }
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
            coachSection(title: "Next step", text: card.nextStep)
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
}
