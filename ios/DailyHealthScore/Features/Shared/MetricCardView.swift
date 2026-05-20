import SwiftUI

struct MetricCardView: View {
    let title: String
    let summary: String
    let fractionOfGoal: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(summary)
                .font(.subheadline.weight(.medium))
            ProgressView(value: min(max(fractionOfGoal, 0), 1))
                .tint(Color(red: 0.2, green: 0.45, blue: 0.55))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
