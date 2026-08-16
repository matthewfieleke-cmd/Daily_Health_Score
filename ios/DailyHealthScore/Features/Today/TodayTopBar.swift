import SwiftUI

/// Custom top bar for Today: brand mark, title, and the three feature entry
/// points (coach, SMART goals, HRV analysis) plus refresh.
///
/// The title is centered in the gap between the brand mark and the Lifestyle
/// Coach icon — not left-aligned against the mark, and not centered on the
/// full screen width.
struct TodayTopBar: View {
    let smartGoalAttentionCount: Int
    let onAskCoach: () -> Void
    let onOpenSMARTGoals: () -> Void
    let onOpenHRVAnalysis: () -> Void
    let onRefresh: () -> Void

    private let brandSize = AppTheme.Layout.todayBrandSize
    private let iconSize = AppTheme.Layout.todayFeatureIconSize

    var body: some View {
        HStack(spacing: 12) {
            Image("BrandMark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: brandSize, height: brandSize)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            Text("Daily Health Score")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                iconButton(
                    imageName: "DHSLifestyleCoach",
                    label: "Ask DHS Lifestyle Coach",
                    action: onAskCoach
                )

                iconButton(
                    imageName: "SMARTGoals",
                    label: smartGoalAttentionCount > 0
                        ? "SMART goals, \(smartGoalAttentionCount) need attention"
                        : "SMART goals",
                    badge: smartGoalAttentionCount,
                    action: onOpenSMARTGoals
                )

                iconButton(
                    imageName: "HRVAnalysis",
                    label: "HRV analysis",
                    action: onOpenHRVAnalysis
                )

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3.weight(.semibold))
                        .frame(width: iconSize, height: iconSize)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Refresh from Apple Health")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: AppTheme.Layout.todayTopBarHeight)
        .frame(maxWidth: .infinity)
        .background(AppTheme.screenBackground)
        .tint(AppTheme.primary)
        .accessibilityElement(children: .contain)
    }

    private func iconButton(
        imageName: String,
        label: String,
        badge: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(
                                Capsule()
                                    .fill(AppTheme.primary)
                                    .overlay(Capsule().stroke(AppTheme.screenBackground, lineWidth: 1.5))
                            )
                            .offset(x: 6, y: -5)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
