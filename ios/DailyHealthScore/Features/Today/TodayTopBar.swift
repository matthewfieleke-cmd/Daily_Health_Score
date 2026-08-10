import SwiftUI

/// Custom top bar for Today: brand mark, title, Ask coach, refresh.
struct TodayTopBar: View {
    let onAskCoach: () -> Void
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image("BrandMark")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)

            Spacer(minLength: 8)

            Text("Daily Health Score")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .layoutPriority(1)

            Spacer(minLength: 8)

            HStack(spacing: 14) {
                Button(action: onAskCoach) {
                    Image("DHSLifestyleCoach")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ask DHS Lifestyle Coach")

                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh from Apple Health")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: AppTheme.Layout.navigationBarRowHeight)
        .frame(maxWidth: .infinity)
        .background(AppTheme.screenBackground)
        .tint(AppTheme.primary)
        .accessibilityElement(children: .contain)
    }
}
