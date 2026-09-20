import SwiftUI

/// Home coach card: one health line and doors into chat. Leftover height
/// stays the grouped screen — never a white hole inside the card.
struct TodayLifestyleCoachCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController

    let record: DailyRecord?
    var onContinue: (() -> Void)?
    var onWhatsOnMyMind: (() -> Void)?
    var onRecents: (() -> Void)?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let window = CoachTimeOfDay.current(from: context.date)
            cardStack
                .task(id: "\(record?.date ?? "")#\(window.rawValue)#\(appState.smartGoalsRevision)") {
                    guard let record else { return }
                    await coach.ensureDailyCard(
                        for: record,
                        records: appState.recordStore.records,
                        goals: appState.smartGoalStore.goals,
                        hrvSensitivity: appState.settingsStore.hrvSensitivity,
                        now: context.date
                    )
                }
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

    private var cardStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if coach.isGeneratingDailyCard && coach.dailyCard == nil {
                loadingBody
            } else if let card = displayedCard {
                healthLine(card)
            }

            doors
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
    }

    private var displayedCard: DailyCoachCardContent? {
        if let card = coach.dailyCard { return card }
        guard !coach.isGeneratingDailyCard, let record else { return nil }
        return HomeCoachCardCopy.fallbackCard(for: record)
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

    private var loadingBody: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Preparing today’s note.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func healthLine(_ card: DailyCoachCardContent) -> some View {
        let line = card.healthLine.isEmpty ? card.whereYouAre : card.healthLine
        return ViewThatFits(in: .vertical) {
            Text(line).font(.footnote)
            Text(line).font(.caption)
            Text(line).font(.caption2)
        }
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(line)
    }

    @ViewBuilder
    private var doors: some View {
        let continueTitle = displayedCard?.continueTitle.isEmpty == false
            ? displayedCard?.continueTitle
            : CoachThreadLogic.continueThread(in: coach.memory.threads)?.title
        if let onContinue, let continueTitle, !continueTitle.isEmpty {
            doorButton(
                title: "Continue \(continueTitle)",
                systemImage: "arrow.uturn.backward",
                action: onContinue
            )
        }
        if let onWhatsOnMyMind {
            doorButton(
                title: "What's on my mind",
                systemImage: "bubble.left.and.text.bubble.right",
                action: onWhatsOnMyMind
            )
        }
        if let onRecents {
            Button(action: onRecents) {
                Text("All chats")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("All coach chats")
        }
    }

    private func doorButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption)
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
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
