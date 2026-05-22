import SwiftUI

/// Diagnostic view that lists every HealthKit sleep sample our query sees for
/// the wake day starting at midnight today. Designed to be compared
/// side-by-side with Apple Health → Sleep → Show More Sleep Data.
///
/// Each row shows: stage, source app, start → end, duration. Awake / In Bed
/// samples are visually de-emphasized because they don't contribute to our
/// "Time Asleep" total. A summary header shows the attributed total (the
/// number that appears on Today) plus the raw sum of all asleep samples and
/// the list of HealthKit sources contributing data.
struct SleepDiagnosticView: View {
    @EnvironmentObject private var appState: AppState
    @State private var diagnostic: SleepDiagnostic?
    @State private var loading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if loading {
                        HStack { ProgressView(); Text("Loading…") }
                            .padding()
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding()
                    } else if let diagnostic {
                        summary(for: diagnostic)
                        if diagnostic.allSamples.isEmpty {
                            Text("No sleep samples in [\(formatted(diagnostic.windowStart)), \(formatted(diagnostic.windowEnd))).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        } else {
                            samplesList(for: diagnostic)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Sleep diagnostic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(loading)
                }
            }
            .task { await load() }
        }
    }

    // MARK: - Loading

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let today = DateHelpers.localDateKey()
            diagnostic = try await appState.healthKit.sleepDiagnostic(forDateKey: today)
            errorMessage = nil
        } catch {
            diagnostic = nil
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Summary card

    private func summary(for d: SleepDiagnostic) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            row(label: "Date", value: d.dateKey)
            row(label: "Window start", value: formatted(d.windowStart))
            row(label: "Window end", value: formatted(d.windowEnd))
            row(label: "Attributed total", value: formattedHours(d.attributedHours))
            row(label: "Sum of asleep samples", value: formattedHours(d.sumOfAllAsleepDurationsHours))
            row(label: "Total samples", value: "\(d.allSamples.count)")
            row(label: "Asleep samples", value: "\(d.asleepSamples.count)")
            row(label: "Sources", value: d.sourcesSeen.isEmpty ? "—" : d.sourcesSeen.joined(separator: ", "))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func row(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.footnote)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }

    // MARK: - Samples list

    private func samplesList(for d: SleepDiagnostic) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Samples (sorted by start)")
                .font(.headline)
                .padding(.bottom, 6)

            ForEach(d.allSamples) { sample in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(sample.stage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(sample.isAsleep ? AppTheme.primary : .secondary)
                        if !sample.isAsleep {
                            Text("(not counted)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        Text(durationLabel(sample.durationSeconds))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 8) {
                        Text(sample.sourceName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text("\(formatted(sample.start)) → \(formatted(sample.end))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 8)
                .opacity(sample.isAsleep ? 1.0 : 0.55)
                if sample.id != d.allSamples.last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Formatting

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, HH:mm:ss"
        return f.string(from: date)
    }

    private func formattedHours(_ hours: Double) -> String {
        let total = Int((hours * 3600).rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return "\(h)h \(m)m \(s)s  (\(String(format: "%.3f", hours)) h)"
    }

    private func durationLabel(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
