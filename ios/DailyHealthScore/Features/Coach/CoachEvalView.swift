import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Runs the regression prompts through the live Coach pipeline without saving
/// anything, so every prompt change is compared rather than guessed at.
struct CoachEvalView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var coach: LifestyleCoachController

    @State private var results: [String: CoachEvalResult] = [:]
    @State private var runningID: String?
    @State private var isRunningAll = false
    @State private var checked: Set<String> = []
    @State private var copied = false

    private var todayRecord: DailyRecord? {
        appState.recordStore.records.first { $0.date == DateHelpers.localDateKey() }
    }

    private var requestCount: Int {
        CoachEvalPrompts.all.reduce(0) { $0 + $1.requestCount }
    }

    var body: some View {
        List {
            Section {
                Text("Each prompt runs through the real pipeline — Private Cloud Compute with reasoning and tools when available — using your current memory files. Conversation regressions keep their follow-ups in one throwaway thread; the fallback case is forced on-device. Nothing is saved: no chat, no notes, no card. A full run makes \(requestCount) model requests plus retries and tool calls.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(CoachModelProvider.serverQuotaSummary)
                    .font(.footnote.weight(.medium))
                Button {
                    runAll()
                } label: {
                    Label(isRunningAll ? "Running…" : "Run all \(requestCount) turns", systemImage: "play.fill")
                }
                .disabled(isRunningAll || runningID != nil)
                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = CoachEvalPrompts.export(results: orderedResults)
                    #endif
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy results as text", systemImage: "doc.on.doc")
                }
                .disabled(results.isEmpty)
            }
            ForEach(CoachEvalPrompts.all) { prompt in
                Section {
                    Text(prompt.displayText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let result = results[prompt.id] {
                        if let error = result.error, !error.isEmpty {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else {
                            CoachMarkdownText(text: result.reply, font: .callout)
                            Text("\(result.tier == .privateCloud ? "Private Cloud Compute" : "On-device") · \(result.shape.rawValue) · \(String(format: "%.1f", result.seconds))s · \(CoachReplyPolish.wordCount(result.reply)) words")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let reason = result.fallbackReason, !reason.isEmpty {
                                Text("Fell back to on-device because: \(reason)")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                            if let draft = result.draft {
                                Text("Draft: \(draft)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Tools: \(result.toolsUsed.isEmpty ? "none" : result.toolsUsed.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if !result.memoryNotes.isEmpty {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Memory the Coach would have written")
                                        .font(.caption.weight(.semibold))
                                    ForEach(result.memoryNotes, id: \.self) { note in
                                        Text("• \(note)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        ForEach(CoachEvalPrompts.rubric(for: prompt), id: \.self) { line in
                            let key = "\(prompt.id)#\(line)"
                            Button {
                                if checked.contains(key) { checked.remove(key) } else { checked.insert(key) }
                            } label: {
                                Label(line, systemImage: checked.contains(key) ? "checkmark.circle.fill" : "circle")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        run(prompt)
                    } label: {
                        if runningID == prompt.id {
                            HStack { ProgressView(); Text("Thinking…") }
                        } else {
                            Label(results[prompt.id] == nil ? "Run" : "Run again", systemImage: "play")
                        }
                    }
                    .disabled(runningID != nil || isRunningAll)
                } header: {
                    Text(prompt.title)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Coach eval")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: results.count) { _, _ in copied = false }
    }

    private var orderedResults: [CoachEvalResult] {
        CoachEvalPrompts.all.compactMap { results[$0.id] }
    }

    private func run(_ prompt: CoachEvalPrompt) {
        runningID = prompt.id
        Task {
            let result = await coach.evaluate(
                prompt: prompt.text,
                promptID: prompt.id,
                messages: prompt.messages,
                forcedTier: prompt.forcedTier,
                todayRecord: todayRecord,
                records: appState.recordStore.records,
                goals: appState.smartGoalStore.goals,
                activities: appState.smartGoalStore.activities,
                hrvSensitivity: appState.settingsStore.hrvSensitivity,
                bodyTrend: appState.bodyTrend
            )
            results[prompt.id] = result
            runningID = nil
        }
    }

    private func runAll() {
        isRunningAll = true
        Task {
            for prompt in CoachEvalPrompts.all {
                runningID = prompt.id
                let result = await coach.evaluate(
                    prompt: prompt.text,
                    promptID: prompt.id,
                    messages: prompt.messages,
                    forcedTier: prompt.forcedTier,
                    todayRecord: todayRecord,
                    records: appState.recordStore.records,
                    goals: appState.smartGoalStore.goals,
                    activities: appState.smartGoalStore.activities,
                    hrvSensitivity: appState.settingsStore.hrvSensitivity,
                    bodyTrend: appState.bodyTrend
                )
                results[prompt.id] = result
            }
            runningID = nil
            isRunningAll = false
        }
    }
}
