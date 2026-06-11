import SwiftUI

/// Compact, scrollable reference dialog with a fixed header and close control.
struct InfoScrollDialog: View {
    let title: String
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .opacity(0.35)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismiss)
                    .accessibilityHidden(true)

                card(maxHeight: proxy.size.height * 0.5)
                    .frame(maxWidth: min(proxy.size.width - 40, 360))
                    .frame(maxHeight: proxy.size.height * 0.5)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }

    private func card(maxHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .background(.quaternary)

            ScrollView {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
            }
            .frame(maxHeight: max(120, maxHeight - 64))
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Layout.cardCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 10)
        .transition(
            .scale(scale: 0.94, anchor: .center)
                .combined(with: .opacity)
        )
    }
}

extension View {
    func infoScrollDialog(
        isPresented: Binding<Bool>,
        title: String,
        text: String
    ) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                InfoScrollDialog(title: title, text: text) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        isPresented.wrappedValue = false
                    }
                }
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isPresented.wrappedValue)
    }
}
