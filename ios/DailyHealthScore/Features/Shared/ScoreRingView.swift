import SwiftUI

/// Circular progress ring showing today's daily health score out of 10.
struct ScoreRingView: View {
    let score: Double
    var animationProgress: Double = 1
    var lineWidth: CGFloat = 14
    var size: CGFloat = 168
    /// Hero cards sit on the navy gradient; use light type and track.
    var onDarkBackground: Bool = false

    private var displayedScore: Double {
        score * max(0, min(animationProgress, 1))
    }

    private var fraction: Double {
        max(0, min(displayedScore / 10.0, 1))
    }

    private var scoreFontSize: CGFloat { max(24, size * 0.40) }

    private var ringColor: Color {
        let t = fraction
        return Color(
            light: blend(
                from: UIColor(AppTheme.primary.resolve(style: .light)),
                to:   UIColor(AppTheme.leaf.resolve(style: .light)),
                t:    t
            ),
            dark: blend(
                from: UIColor(AppTheme.primary.resolve(style: .dark)),
                to:   UIColor(AppTheme.leaf.resolve(style: .dark)),
                t:    t
            )
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    onDarkBackground ? Color.white.opacity(0.20) : AppTheme.primary.opacity(0.12),
                    lineWidth: lineWidth
                )

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: size >= 130 ? 2 : 1) {
                Text(formatted(displayedScore))
                    .font(.system(size: scoreFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(onDarkBackground ? Color.white : AppTheme.backgroundDeep)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .contentTransition(.numericText(value: displayedScore))
                Text("/ 10")
                    .font(size >= 130 ? .subheadline.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundStyle(onDarkBackground ? Color.white.opacity(0.58) : Color.secondary)
            }
        }
        .animation(DialUpAnimation.timing, value: animationProgress)
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Daily score")
        .accessibilityValue("\(formatted(score)) out of ten")
    }

    private func formatted(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return String(format: "%.1f", rounded)
    }

    private func blend(from: UIColor, to: UIColor, t: Double) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        from.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        to.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let tt = CGFloat(t)
        return Color(
            red:   Double(r1 + (r2 - r1) * tt),
            green: Double(g1 + (g2 - g1) * tt),
            blue:  Double(b1 + (b2 - b1) * tt),
            opacity: 1
        )
    }
}

extension Color {
    func resolve(style: UIUserInterfaceStyle) -> Color {
        let trait = UITraitCollection(userInterfaceStyle: style)
        let resolved = UIColor(self).resolvedColor(with: trait)
        return Color(resolved)
    }
}
