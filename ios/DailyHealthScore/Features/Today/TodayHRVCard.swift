import SwiftUI

struct TodayHRVCard: View {
    let summary: HRVRollingSummary
    let onInfoTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(AppTheme.primary.opacity(0.12)))

                Text("HRV")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About heart rate variability trends")
            }

            if let averageLine = averageLine {
                Text(averageLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            } else {
                Text("No HRV data yet")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Text(trendLine)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart Rate Variability")
    }

    private var averageLine: String? {
        guard let averageMs = summary.averageMs else { return nil }
        let rounded = Int(averageMs.rounded())
        if summary.nightsWithData < summary.nightsInWindow {
            return "7-day average: \(rounded) ms (\(summary.nightsWithData) of \(summary.nightsInWindow) nights)"
        }
        return "7-day average: \(rounded) ms"
    }

    private var trendLine: String {
        switch summary.trend {
        case .up:
            return "↑ Trending up"
        case .down:
            return "↓ Trending down"
        case .steady:
            return "→ Holding steady"
        case .needsMoreHistory:
            if summary.averageMs == nil {
                return "Wear your Apple Watch during sleep to build history."
            }
            return "Trend needs more history"
        }
    }
}
