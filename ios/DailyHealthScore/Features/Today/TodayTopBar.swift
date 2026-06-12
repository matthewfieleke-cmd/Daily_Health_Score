import SwiftUI

/// Custom top bar for Today: enlarged logo (leading), title centered in the gap
/// before the trailing action buttons.
struct TodayTopBar: View {
    let onDiscouragement: () -> Void
    let onMotivation: () -> Void
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

            HStack(spacing: 16) {
                Button(action: onDiscouragement) {
                    Image(systemName: "heart.text.square")
                }
                .accessibilityLabel("Feeling discouraged")

                Button(action: onMotivation) {
                    Image("HikerOnHill")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                }
                .accessibilityLabel("Need motivation")

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
