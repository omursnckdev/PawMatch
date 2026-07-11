import SwiftUI

/// Likes tab. "See who liked you" is a PawMatch Plus feature (§3): free users
/// get a paywall prompt; Plus users see the grid of pets that liked them.
struct LikesView: View {
    @ObservedObject private var entitlements = EntitlementManager.shared
    @StateObject private var viewModel = LikesViewModel()
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Group {
                if entitlements.isPremium {
                    plusContent
                } else {
                    lockedContent
                }
            }
            .navigationTitle("tab.likes")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(source: .likesTab, onDismiss: { showPaywall = false })
        }
    }

    @ViewBuilder
    private var plusContent: some View {
        if viewModel.isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { await viewModel.load() }
        } else if viewModel.pets.isEmpty {
            PlaceholderView(
                systemImage: "heart",
                title: "likes.empty.title",
                message: "likes.empty.message"
            )
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(viewModel.pets) { pet in
                        PetCardView(pet: pet)
                            .frame(height: 220)
                    }
                }
                .padding()
            }
            .refreshable { await viewModel.load() }
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.pawOrange)
            Text("placeholder.likes.title").font(.pawHeading(20))
            Text("placeholder.likes.message")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("likes.unlock") { showPaywall = true }
                .buttonStyle(PrimaryButtonStyle())
                .fixedSize()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
