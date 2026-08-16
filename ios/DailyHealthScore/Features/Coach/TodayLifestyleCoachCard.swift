import SwiftUI

/// Home coach card: two complete beats that hug their content. Leftover
/// height stays the grouped screen behind the card — never a white hole
/// inside it. Coaching copy is never ellipsized; if the remaining Home
/// height is tight, `ViewThatFits` shrinks the type instead.
struct TodayLifestyleCoachCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController

    let record: DailyRecord?
    var onAskCoach: (() -> Void)?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let window = CoachTimeOfDay.current(from: context.date)
            cardStack
                .task(id: "\(record?.date ?? "")#\(window.rawValue)") {
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
                twoBeats(card)
            }

            askCoachButton
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
    }

    /// Model card when we have one; otherwise a complete two-beat note from
    /// today's numbers so Home is useful even with Apple Intelligence off.
    private var displayedCard: DailyCoachCardContent? {
        if let card = coach.dailyCard { return card }
        guard !coach.isGeneratingDailyCard, let record else { return nil }
        return HomeCoachCardCopy.fallbackCard(for: record)
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

    private var loadingBody: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Preparing today’s coaching note.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Shrink type to fit the remaining Home height; never clip a sentence.
    private func twoBeats(_ card: DailyCoachCardContent) -> some View {
        ViewThatFits(in: .vertical) {
            TwoBeatCopy(whereYouAre: card.whereYouAre, nextMove: card.nextMove, style: .footnote)
            TwoBeatCopy(whereYouAre: card.whereYouAre, nextMove: card.nextMove, style: .caption)
            TwoBeatCopy(whereYouAre: card.whereYouAre, nextMove: card.nextMove, style: .caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Full sentences at one type size. No `lineLimit`, no spacer.
private struct TwoBeatCopy: View {
    enum Style {
        case footnote, caption, caption2

        var bodyFont: Font {
            switch self {
            case .footnote: return .footnote
            case .caption: return .caption
            case .caption2: return .caption2
            }
        }

        var actionFont: Font {
            switch self {
            case .footnote: return .footnote.weight(.medium)
            case .caption: return .caption.weight(.medium)
            case .caption2: return .caption2.weight(.medium)
            }
        }
    }

    let whereYouAre: String
    let nextMove: String
    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(whereYouAre)
                .font(style.bodyFont)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(whereYouAre)

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(style.bodyFont)
                    .foregroundStyle(AppTheme.leaf)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("RIGHT NOW")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.leaf)
                        .tracking(0.5)
                    Text(nextMove)
                        .font(style.actionFont)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(nextMove)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.leaf.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}
