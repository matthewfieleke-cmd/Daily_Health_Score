import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The Home card is a short feed of thoughts the Coach chose. Active SMART
/// goals sit under them, with Done, whenever there is something to log.
/// Reply opens a chat that starts with the card's words. Leftover height stays
/// the grouped screen — never a white hole inside the card.
struct TodayCoachCheckInCard: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController

    let record: DailyRecord?
    var onReply: () -> Void
    var onContinueReply: (UUID) -> Void
    var onIntake: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let kind = CoachCheckInLogic.kind(for: context.date)
            // The shape of the day is part of the id, so a Health sync that
            // lands the first numbers or crosses a goal re-evaluates the card.
            let signature = record.map { CoachCheckInLogic.statusSignature(for: $0) } ?? ""
            cardStack(kind: kind, now: context.date)
                .task(id: "\(record?.date ?? "")#\(kind.rawValue)#\(signature)#\(appState.smartGoalsRevision)#\(coach.memory.memoryRevision)") {
                    guard let record else { return }
                    await coach.ensureCheckIn(
                        for: record,
                        records: appState.recordStore.records,
                        goals: appState.smartGoalStore.goals,
                        activities: appState.smartGoalStore.activities,
                        hrvSensitivity: appState.settingsStore.hrvSensitivity,
                        bodyTrend: appState.bodyTrend,
                        now: context.date
                    )
                }
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
                    force: true
                )
            }
        }
    }

    private func cardStack(kind: CoachCheckInKind, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader

            // Natural height when it fits; only an overflowing card scrolls.
            ViewThatFits(in: .vertical) {
                noteBody(kind: kind, now: now)
                ScrollView(.vertical, showsIndicators: false) {
                    noteBody(kind: kind, now: now)
                }
            }

            door(kind: kind, now: now)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
    }

    private func noteBody(kind: CoachCheckInKind, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if coach.memory.needsAcquaintance {
                acquaintBody
            } else if coach.isGeneratingCheckIn && coach.checkIn == nil {
                loadingBody
            } else if let card = displayedCheckIn(kind: kind, now: now) {
                checkInBody(card)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The generated card for this window, or a deterministic one while it writes.
    private func displayedCheckIn(kind: CoachCheckInKind, now: Date) -> CoachCheckIn? {
        if let card = coach.checkIn, card.kind == kind, card.dateKey == record?.date { return card }
        guard !coach.isGeneratingCheckIn, let record else { return nil }
        return HomeCoachCardCopy.fallbackCheckIn(for: record, kind: kind, now: now)
    }

    private var cardHeader: some View {
        HStack(spacing: 10) {
            Image("DHSLifestyleCoach")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("DHS Lifestyle Coach")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if coach.memory.needsAcquaintance {
                    Label("Intake", systemImage: "list.clipboard")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Today")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var loadingBody: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Writing today’s note.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var acquaintBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let record {
                Text(HomeCoachCardCopy.healthLine(for: record))
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Intake is a short form, so what your coach says fits your life before the numbers.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func checkInBody(_ card: CoachCheckIn) -> some View {
        ForEach(Array(card.displayLines.enumerated()), id: \.offset) { _, line in
            Text(line)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }

        goalRows
    }

    /// Active SMART goals with a tap to log. Progress comes straight from the
    /// store, so a Done tap updates the row without rewriting the card.
    @ViewBuilder
    private var goalRows: some View {
        let rows = CoachCheckInLogic.goalRows(
            goals: appState.smartGoalStore.goals,
            activities: appState.smartGoalStore.activities,
            todayKey: record?.date ?? DateHelpers.localDateKey()
        )
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(rows.prefix(3)) { row in
                    goalRow(row)
                }
                if rows.count > 3 {
                    Text("\(rows.count - 3) more in SMART goals")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(AppTheme.screenBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func goalRow(_ row: CoachCheckInGoalRow) -> some View {
        HStack(spacing: 8) {
            Image(systemName: row.loggedToday ? "checkmark.circle.fill" : "circle")
                .font(.subheadline)
                .foregroundStyle(row.loggedToday ? AppTheme.leaf : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text(row.loggedToday ? "Logged today · \(row.progressText)" : row.progressText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if row.canLog {
                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    _ = appState.smartGoalStore.recordCheckIn(
                        goalId: row.goalId,
                        source: .iPhone,
                        occurredAt: Date()
                    )
                } label: {
                    Text("Done")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.primary.opacity(0.12))
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Log \(row.title) as done today")
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func door(kind: CoachCheckInKind, now: Date) -> some View {
        if coach.memory.needsAcquaintance {
            doorButton(title: "Intake", systemImage: "list.clipboard", action: onIntake)
        } else if let card = coach.memory.cachedCheckIn,
                  card.kind == kind,
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
