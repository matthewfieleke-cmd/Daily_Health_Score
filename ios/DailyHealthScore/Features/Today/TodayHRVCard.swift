import SwiftUI

struct TodayHRVCard: View {
    let analysis: HRVAnalysis
    let onInfoTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
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

            VStack(spacing: 10) {
                Button(action: onInfoTap) {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("About heart rate variability trends")

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
        .cardShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Heart Rate Variability")
        .accessibilityHint("Opens HRV trend graph")
    }

    private var averageLine: String? {
        guard let averageMs = analysis.acuteAverageMs else { return nil }
        let rounded = Int(averageMs.rounded())
        if analysis.acuteNightsWithData < analysis.acuteWindowNights {
            return "7-day average: \(rounded) ms (\(analysis.acuteNightsWithData) of \(analysis.acuteWindowNights) nights)"
        }
        return "7-day average: \(rounded) ms"
    }

    private var trendLine: String {
        switch analysis.state {
        case .buildingBaseline:
            if analysis.acuteAverageMs == nil {
                return "Wear your Apple Watch during sleep to build history."
            }
            return "Building your usual range"
        case .ready(let result):
            let base: String
            switch result.status {
            case .withinRange: base = "In your usual range"
            case .belowRange: base = "Below your usual range"
            case .aboveRange: base = "Above your usual range"
            }
            return result.isHighVariability ? "\(base) · more variable than usual" : base
        }
    }
}
