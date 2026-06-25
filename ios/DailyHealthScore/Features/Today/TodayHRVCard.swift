import SwiftUI

struct TodayHRVCard: View {
    let result: DHSHRVStudyResult?
    let onInfoTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(AppTheme.primary.opacity(0.12)))

                    Text("Daily Health Score Correlation with HRV")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)
                }

                Text(summaryLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(windowLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                weeklyCue
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
        .accessibilityLabel("Daily Health Score Correlation with HRV")
        .accessibilityHint("Opens DHS and HRV correlation details")
    }

    private var summaryLine: String {
        guard let result, result.hasAnyWeeklyData else {
            return "Wear your Apple Watch during sleep to start comparing DHS and HRV trends."
        }
        return result.correlation.displayLabel == "Not enough data yet"
            ? "Building your 13-week trend relationship."
            : "\(result.correlation.displayLabel) across weekly trends."
    }

    private var windowLine: String {
        guard let result else { return "Latest 91 complete DHS days" }
        return "\(compactRange(result.dhsStartDate, result.dhsEndDate)) DHS paired with \(compactRange(result.hrvStartDate, result.hrvEndDate)) sleep HRV"
    }

    private var weeklyCue: some View {
        HStack(spacing: 3) {
            ForEach(1 ... DHSHRVStudyResult.weeklyPointCount, id: \.self) { week in
                let point = result?.weeklyPoints.first { $0.weekIndex == week }
                Capsule()
                    .fill(cueColor(for: point))
                    .frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }

    private func cueColor(for point: DHSHRVWeeklyPoint?) -> Color {
        guard let point else { return .secondary.opacity(0.14) }
        if point.averageDHS != nil, point.averageHRV != nil {
            return AppTheme.primary.opacity(point.hrvCompleteness == .sparse ? 0.35 : 0.85)
        }
        if point.averageDHS != nil || point.averageHRV != nil {
            return AppTheme.leaf.opacity(0.35)
        }
        return .secondary.opacity(0.14)
    }

    private func compactRange(_ start: String, _ end: String) -> String {
        guard let startDate = DateHelpers.date(from: start),
              let endDate = DateHelpers.date(from: end) else {
            return "\(start)-\(end)"
        }
        let format = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(startDate.formatted(format))-\(endDate.formatted(format))"
    }
}
