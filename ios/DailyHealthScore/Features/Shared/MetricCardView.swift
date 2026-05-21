import SwiftUI

/// A single metric card on the Today screen — icon, label, value, and a
/// progress bar showing fraction of goal. Brand-tinted per metric.
struct MetricCardView: View {
    let title: String
    let valueText: String
    let scoreText: String
    let maxScoreText: String
    let fractionOfGoal: Double
    let systemImage: String
    let tint: Color

    private var capped: Double { max(0, min(fractionOfGoal, 1)) }
    private var atOrOverGoal: Bool { fractionOfGoal >= 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle().fill(tint.opacity(0.15))
                    )
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if atOrOverGoal {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.leaf)
                        .accessibilityLabel("Goal met")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(valueText)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                Text("\(scoreText) / \(maxScoreText)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.15))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * capped)
                        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: capped)
                }
            }
            .frame(height: 6)
        }
        .dhsCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(valueText), score \(scoreText) of \(maxScoreText)")
    }
}
