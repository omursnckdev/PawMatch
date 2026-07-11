import SwiftUI

/// The main tab bar shell (§4). Milestone 3 wires the Swipe and Profile tabs;
/// Matches, Chat, and Likes are placeholders filled in Milestones 4–5.
struct MainTabView: View {
    let pets: [Pet]
    @ObservedObject var homeViewModel: HomeViewModel
    let onSignOut: () -> Void

    /// The pet the user swipes as. Free users have exactly one; a multi-pet
    /// switcher for Plus users is a later enhancement.
    private var activePet: Pet? { pets.first }

    var body: some View {
        TabView {
            Group {
                if let activePet {
                    SwipeDeckView(activePet: activePet)
                } else {
                    PlaceholderView(
                        systemImage: "pawprint",
                        title: "managePets.empty",
                        message: "deck.empty.message"
                    )
                }
            }
            .tabItem { Label("tab.swipe", systemImage: "flame.fill") }

            PlaceholderView(
                systemImage: "square.grid.2x2.fill",
                title: "placeholder.matches.title",
                message: "placeholder.matches.message"
            )
            .tabItem { Label("tab.matches", systemImage: "square.grid.2x2.fill") }

            PlaceholderView(
                systemImage: "bubble.left.and.bubble.right.fill",
                title: "placeholder.chat.title",
                message: "placeholder.chat.message"
            )
            .tabItem { Label("tab.chat", systemImage: "bubble.left.and.bubble.right.fill") }

            PlaceholderView(
                systemImage: "heart.fill",
                title: "placeholder.likes.title",
                message: "placeholder.likes.message"
            )
            .tabItem { Label("tab.likes", systemImage: "heart.fill") }

            ManagePetsView(pets: pets, homeViewModel: homeViewModel, onSignOut: onSignOut)
                .tabItem { Label("tab.profile", systemImage: "person.crop.circle.fill") }
        }
        .tint(Color.pawOrange)
    }
}
