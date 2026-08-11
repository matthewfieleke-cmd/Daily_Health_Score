import SwiftUI

/// Custom top bar for Today: brand mark, title, and the three feature entry
/// points (coach, SMART goals, HRV analysis) plus refresh. These icons replace
/// the cards that used to push Today into a scroll.
struct TodayTopBar: View {
    let smartGoalAttentionCount: Int
    let onAskCoach: () -> Void
    let onOpenSMARTGoals: () -> Void
    let onOpenHRVAnalysis: () -> Void
    let onRefresh: () -> Void

    private let iconSize: CGFloat = 28

    var body: some View {
        HStack(spacing: 10) {
            Image("BrandMark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)

            Text("Daily Health Score")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 6)

            HStack(spacing: 2) {
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
                        .font(.body.weight(.medium))
                }
                .accessibilityLabel("Refresh from Apple Health")
                .padding(.leading, 2)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: AppTheme.Layout.navigationBarRowHeight)
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
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .frame(minWidth: 15, minHeight: 15)
                            .background(
                                Capsule()
                                    .fill(AppTheme.primary)
                                    .overlay(Capsule().stroke(AppTheme.screenBackground, lineWidth: 1.5))
                            )
                            .offset(x: 6, y: -5)
                    }
                }
                // Padding rather than a larger icon: keeps the 28pt look while
                // giving each button a comfortable tap target.
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
