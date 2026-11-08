import SwiftUI

/// The Home card is three insights from the last 7, 30, and 90 days.
/// Reply opens a chat that starts with those words. Leftover height stays
/// the grouped screen.
struct TodayCoachCheckInCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController

    let record: DailyRecord?
    var onReply: () -> Void
    var onContinueReply: (UUID) -> Void
    var onIntake: () -> Void
    var onShowChart: (TrendMetric) -> Void = { _ in }
    var onShowHealthChart: (CoachHealthMeasure, CoachHealthChart?) -> Void = { _, _ in }

    var body: some View {
        let today = record?.date ?? ""
        let finished = appState.recordStore.records.contains { item in
            item.date < today && (
                item.sleepHours > 0 || item.fiberGrams > 0 || item.movementValue > 0 || item.foodGroups.isLogged
            )
        }
        let cachedToday = coach.memory.cachedCheckInKey == CoachCheckInLogic.cacheKey(dateKey: today)
        cardStack
            .task(id: "\(today)#\(finished)#\(cachedToday)") {
                guard let record else { return }
                await coach.ensureCheckIn(
                    for: record,
                    records: appState.recordStore.records,
                    goals: appState.smartGoalStore.goals,
                    activities: appState.smartGoalStore.activities,
                    hrvSensitivity: appState.settingsStore.hrvSensitivity,
                    bodyTrend: appState.bodyTrend,
                    scoringSettings: appState.settingsStore.settings
                )
            }
            .onChange(of: appState.userRefreshToken) { _, _ in
                guard let record else { return }
                Task {
                    await coach.ensureCheckIn(
                        for: record,
                        records: appState.recordStore.records,
                        goals: appState.smartGoalStore.goals,
                        activities: appState.smartGoalStore.activities,
                        hrvSensitivity: appState.settingsStore.hrvSensitivity,
                        bodyTrend: appState.bodyTrend,
                        scoringSettings: appState.settingsStore.settings,
                        force: true
                    )
                }
            }
    }

    private var cardStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader
            if coach.isGeneratingCheckIn, coach.checkIn != nil {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Writing new insights.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ViewThatFits(in: .vertical) {
                noteBody
                ScrollView(.vertical, showsIndicators: false) {
                    noteBody
                }
            }
            door
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
    }

    @ViewBuilder
    private var noteBody: some View {
        if let card = coach.checkIn, card.waitingForHealthData {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(CoachInsightTone.allCases) { tone in
                    needsDataPanel(tone)
                }
            }
        } else if let card = coach.checkIn, !card.insights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(card.insights) { panel in
                    if panel.isBlank {
                        blankPanel(panel.tone)
                    } else {
                        filledPanel(panel)
                    }
                }
            }
        } else if let card = coach.checkIn {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(card.displayLines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if coach.isGeneratingCheckIn {
            HStack(spacing: 10) {
                ProgressView()
                Text("Writing your insights.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(CoachInsightTone.allCases) { tone in
                    blankPanel(tone)
                }
            }
        }
    }

    private var cardHeader: some View {
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

    private func filledPanel(_ panel: CoachInsightPanel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(toneColor(panel.tone))
                    .frame(width: 10, height: 10)
                Text("\(panel.tone.name) · \(panel.topic)")
                    .font(.subheadline.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            bullet(Text(panel.finding))
            if !panel.advice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bullet(
                    Text(panel.tone.actionLead).fontWeight(.bold)
                    + Text(" \(panel.advice)")
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(toneColor(panel.tone).opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func blankPanel(_ tone: CoachInsightTone) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(toneColor(tone))
                .frame(width: 10, height: 10)
            Text(tone.name)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(toneColor(tone).opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("\(tone.name), blank")
    }

    private func needsDataPanel(_ tone: CoachInsightTone) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(toneColor(tone))
                    .frame(width: 10, height: 10)
                Text(tone.name)
                    .font(.subheadline.weight(.semibold))
            }
            Text(CoachInsightRecord.needsDataSentence)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(toneColor(tone).opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func bullet(_ text: Text) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
                .font(.footnote.weight(.bold))
            text
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func toneColor(_ tone: CoachInsightTone) -> Color {
        switch tone {
        case .green: return AppTheme.leaf
        case .yellow: return Color(red: 0.85, green: 0.62, blue: 0.10)
        case .red: return Color(red: 0.82, green: 0.28, blue: 0.28)
        }
    }

    @ViewBuilder
    private var door: some View {
        if let card = coach.memory.cachedCheckIn,
           card.dateKey == record?.date,
           let replyID = card.replyThreadID,
           let thread = coach.memory.threads.first(where: { $0.id == replyID }) {
            doorButton(
                title: "Continue · \(thread.title)",
                systemImage: "arrow.uturn.backward",
                action: { onContinueReply(replyID) }
            )
        } else {
            doorButton(title: "Reply", systemImage: "arrowshape.turn.up.left.fill", action: onReply)
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
