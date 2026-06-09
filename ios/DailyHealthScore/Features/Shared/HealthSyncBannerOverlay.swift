import SwiftUI

/// App-wide overlay for the two-phase Apple Health sync status banners.
struct HealthSyncBannerOverlay: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if appState.healthSyncBannerPhase != .hidden {
                HStack {
                    Spacer(minLength: 0)
                    banner
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    )
                )
            }
            Spacer(minLength: 0)
        }
        .safeAreaPadding(.top, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: appState.healthSyncBannerPhase)
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var banner: some View {
        switch appState.healthSyncBannerPhase {
        case .hidden:
            EmptyView()
        case .syncing:
            syncingBanner
        case .complete:
            completeBanner
        }
    }

    private var syncingBanner: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
            Text("Syncing from Apple Health")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .fixedSize()
        .accessibilityLabel("Syncing from Apple Health")
    }

    private var completeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Text("Sync complete!")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.leaf)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .fixedSize()
        .accessibilityLabel("Sync complete")
    }
}
