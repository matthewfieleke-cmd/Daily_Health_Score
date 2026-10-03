import SwiftUI

/// The food-group illustration. Artwork is full color, so it is not tinted.
struct FoodGroupIcon: View {
    let group: FoodGroup

    var body: some View {
        Image(group.imageName)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}
