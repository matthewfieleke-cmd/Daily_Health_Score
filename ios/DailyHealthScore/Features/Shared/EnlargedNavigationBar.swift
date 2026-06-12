import SwiftUI

extension View {
    /// Applies the app's taller inline navigation bar row for tab root screens.
    func enlargedAppNavigationBar(title: String) -> some View {
        navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .frame(minHeight: AppTheme.Layout.navigationBarRowHeight)
                }
            }
    }
}
