import SwiftUI

/// Entry card on Today — always visible, links to SMART Goals list.
struct TodaySMARTGoalsCard: View {
    let attentionCount: Int

    var body: some View {
        NavigationLink {
            SMARTGoalsListView()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "target")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(AppTheme.primary.opacity(0.12)))

                VStack(alignment: .leading, spacing: 1) {
                    Text("SMART Goals")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Set and track accountable goals")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if attentionCount > 0 {
                    Text("\(attentionCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.primary))
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .background(AppTheme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous))
            .cardShadow()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens your SMART goals")
    }
}
