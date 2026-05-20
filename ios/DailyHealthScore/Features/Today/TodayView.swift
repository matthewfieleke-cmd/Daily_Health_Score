import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showDiscouragement = false
    @State private var showMotivation = false
    @State private var discText: String?
    @State private var motivText: String?

    private var todayKey: String { DateHelpers.localDateKey() }

    private var displayRecord: DailyRecord? {
        let records = appState.recordStore.records
        return records.first { $0.date == todayKey } ?? records.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if appState.isSyncingHealth {
                        Text("Syncing from Apple Health…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if let error = appState.lastSyncError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    if let record = displayRecord {
                        if record.date != todayKey {
                            Text("No import for today yet. Showing \(DateHelpers.formatDisplayDate(record.date)).")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(DateHelpers.formatDisplayDate(record.date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(ScoreCalculator.formatDisplayScore(record.totalScore))
                                .font(.system(size: 48, weight: .semibold, design: .rounded))
                            Text("/ 10")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 12) {
                            Button("Feeling discouraged?") {
                                discText = appState.settingsStore.nextDiscouragement()
                                showDiscouragement = true
                            }
                            .buttonStyle(.borderless)

                            Button("Need motivation?") {
                                motivText = appState.settingsStore.nextMotivation()
                                showMotivation = true
                            }
                            .buttonStyle(.borderless)
                        }
                        .font(.subheadline)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            MetricCardView(
                                title: "Sleep",
                                summary: "\(ScoreCalculator.formatDisplayScore(record.sleepHours)) hr → \(ScoreCalculator.formatDisplayScore(record.sleepScore)) / 4",
                                fractionOfGoal: record.sleepHours / record.sleepGoal.rawValue
                            )
                            MetricCardView(
                                title: "Fiber",
                                summary: "\(ScoreCalculator.formatDisplayScore(record.fiberGrams)) g → \(ScoreCalculator.formatDisplayScore(record.fiberScore)) / 4",
                                fractionOfGoal: record.fiberGrams / Double(record.fiberGoal.rawValue)
                            )
                            MetricCardView(
                                title: "Exercise",
                                summary: "\(ScoreCalculator.formatDisplayScore(record.exerciseMinutes)) min → \(ScoreCalculator.formatDisplayScore(record.exerciseScore)) / 2",
                                fractionOfGoal: record.exerciseMinutes / Double(record.exerciseGoalMinutes)
                            )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("PRIMARY FOCUS")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(ScoreCalculator.primaryFocusLabel(record.primaryFocus))
                                .font(.title2.weight(.semibold))
                            Text(record.suggestion)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            Task { await appState.syncTodayFromHealth() }
                        } label: {
                            Text("Refresh from Health")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        ContentUnavailableView(
                            "No data yet",
                            systemImage: "heart.text.square",
                            description: Text("Allow Health access and tap Refresh, or enter a day in Settings.")
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Daily Health Score")
            .sheet(isPresented: $showDiscouragement) {
                ParagraphSheet(title: "Feeling discouraged?", text: discText)
            }
            .sheet(isPresented: $showMotivation) {
                ParagraphSheet(title: "Take responsibility", text: motivText)
            }
        }
    }
}
