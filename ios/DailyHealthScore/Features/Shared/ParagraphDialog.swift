import SwiftUI

/// A lightweight centered dialog used for the "Feeling discouraged?" and
/// "Need motivation?" paragraphs.
struct ParagraphDialog: View {
    let title: String
    let text: String
    let onDismiss: () -> Void

    /// Padding between divider ↔ body text ↔ Thanks button (kept equal).
    private let sectionSpacing: CGFloat = 16

    var body: some View {
        ZStack {
            backdrop
            card
        }
        .transition(.opacity)
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        Color.black
            .opacity(0.35)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
            .accessibilityHidden(true)
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            header
            Divider()
                .background(.quaternary)
            ViewThatFits(in: .vertical) {
                paragraphBody
                ScrollView {
                    paragraphBody
                }
                .frame(maxHeight: 240)
            }
            footer
        }
        .frame(maxWidth: 360)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.Layout.heroCornerRadius, style: .continuous)
                .fill(AppTheme.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Layout.heroCornerRadius, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.30), radius: 30, x: 0, y: 10)
        .padding(.horizontal, 24)
        .transition(
            .scale(scale: 0.92, anchor: .center)
                .combined(with: .opacity)
        )
    }

    private var paragraphBody: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, sectionSpacing)
            .padding(.vertical, sectionSpacing)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Take a breath.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, sectionSpacing)
        .padding(.top, sectionSpacing)
        .padding(.bottom, 10)
    }

    private var footer: some View {
        Button(action: onDismiss) {
            Text("Thanks")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.primary.opacity(0.12))
                .foregroundStyle(AppTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, sectionSpacing)
        .padding(.bottom, sectionSpacing)
    }
}

// MARK: - Presenter modifier

extension View {
    func paragraphDialog(
        isPresented: Binding<Bool>,
        title: String,
        text: String
    ) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                ParagraphDialog(title: title, text: text) {
                    withAnimation(.easeOut(duration: 0.18)) {
                        isPresented.wrappedValue = false
                    }
                }
                .zIndex(1)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isPresented.wrappedValue)
    }
}
