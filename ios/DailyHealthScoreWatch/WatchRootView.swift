import SwiftUI

struct WatchRootView: View {
    var body: some View {
        TabView {
            NavigationStack { TodayBreakdownView() }
            NavigationStack { SMARTCheckInListView() }
        }
        .tabViewStyle(.verticalPage)
    }
}

struct TodayBreakdownView: View {
    @EnvironmentObject private var controller: WatchSnapshotController

    var body: some View {
        if let snapshot = controller.snapshot {
            ScrollView {
                VStack(spacing: 10) {
                    WatchScoreRing(score: snapshot.totalScore, size: 88, lineWidth: 8)
                    Text("of 10")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !snapshot.isForDay(Date()) {
                        Text("Open iPhone to send today.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    ForEach(snapshot.pillars, id: \.name) { pillar in
                        pillarRow(pillar)
                    }
                }
                .padding(.horizontal, 4)
            }
            .navigationTitle("Today")
        } else {
            EmptyHandshakeView()
        }
    }

    private func pillarRow(_ pillar: WatchPillarSnapshot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(pillar.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WatchBrand.tint(for: pillar.name))
                Text("\(pillar.formattedValue) / \(pillar.formattedGoal) \(pillar.unit)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(pillar.formattedPoints)
                .font(.caption.monospacedDigit())
        }
        .padding(.vertical, 2)
    }
}

struct SMARTCheckInListView: View {
    @EnvironmentObject private var controller: WatchSnapshotController

    var body: some View {
        Group {
            if controller.snapshot == nil {
                EmptyHandshakeView()
            } else if let goals = controller.snapshot?.goals, goals.isEmpty {
                Text("Add a SMART goal on iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            } else if let goals = controller.snapshot?.goals {
                List {
                    ForEach(goals) { goal in
                        Button {
                            controller.logCheckIn(goalId: goal.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.specificText)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                                HStack {
                                    Text("\(goal.filledCount)/\(goal.targetCount)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if goal.isComplete {
                                        Text("Complete")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(WatchBrand.leaf)
                                    } else {
                                        Text("Log check-in")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(WatchBrand.primary)
                                    }
                                }
                            }
                        }
                        .disabled(goal.isComplete || !goal.isActive)
                    }
                }
            }
        }
        .navigationTitle("Goals")
    }
}

struct EmptyHandshakeView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "applewatch.and.arrow.forward")
                .font(.title2)
                .foregroundStyle(WatchBrand.primary)
            Text("Open Daily Health Score on iPhone once to send today to your Watch.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct WatchScoreRing: View {
    let score: Double
    var size: CGFloat = 88
    var lineWidth: CGFloat = 8

    private var fraction: Double { max(0, min(score / 10, 1)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(WatchBrand.primary.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    WatchBrand.ringColor(fraction: fraction),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text(String(format: "%.1f", (score * 10).rounded() / 10))
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Daily score")
        .accessibilityValue("\(String(format: "%.1f", score)) out of ten")
    }
}
