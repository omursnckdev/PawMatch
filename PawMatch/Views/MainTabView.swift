import SwiftUI

/// The main tab bar shell (§4). Milestone 4 wires Matches and Chat; the Likes
/// tab remains a Plus paywall placeholder until Milestone 5.
struct MainTabView: View {
    let pets: [Pet]
    @ObservedObject var homeViewModel: HomeViewModel
    let onSignOut: () -> Void

    @StateObject private var matchObserver = MatchObserver()
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared
    @State private var selectedTab: Tab = .swipe
    @AppStorage("didPrimeNotifications") private var didPrimeNotifications = false
    @AppStorage("didPrimeTracking") private var didPrimeTracking = false
    @State private var showNotificationPriming = false
    @State private var showTrackingPriming = false

    enum Tab: Hashable {
        case swipe, matches, chat, likes, profile
    }

    /// The pet the user swipes as. Free users have exactly one; a multi-pet
    /// switcher for Plus users is a later enhancement.
    private var activePet: Pet? { pets.first }

    var body: some View {
        TabView(selection: $selectedTab) {
            swipeTab
                .tabItem { Label("tab.swipe", systemImage: "flame.fill") }
                .tag(Tab.swipe)

            MatchesView()
                .tabItem { Label("tab.matches", systemImage: "square.grid.2x2.fill") }
                .tag(Tab.matches)

            ChatListView()
                .tabItem { Label("tab.chat", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(Tab.chat)

            LikesView()
                .tabItem { Label("tab.likes", systemImage: "heart.fill") }
                .tag(Tab.likes)

            ManagePetsView(pets: pets, homeViewModel: homeViewModel, onSignOut: onSignOut)
                .tabItem { Label("tab.profile", systemImage: "person.crop.circle.fill") }
                .tag(Tab.profile)
        }
        .tint(Color.pawOrange)
        .onAppear {
            matchObserver.start()
            Task { await NotificationService.shared.syncToken() }
            if !didPrimeNotifications {
                showNotificationPriming = true
            } else {
                maybePrimeTracking()
            }
        }
        .onChange(of: deepLinkRouter.pendingMatchId) { _, matchId in
            if matchId != nil { selectedTab = .chat }
        }
        .sheet(isPresented: $showNotificationPriming, onDismiss: maybePrimeTracking) {
            PermissionPrimingView(
                systemImage: "bell.badge.fill",
                title: "notif.priming.title",
                message: "notif.priming.message",
                primaryButtonTitle: "notif.priming.enable",
                onContinue: {
                    didPrimeNotifications = true
                    showNotificationPriming = false
                    Task { await NotificationService.shared.requestAuthorization() }
                },
                onSkip: {
                    didPrimeNotifications = true
                    showNotificationPriming = false
                }
            )
        }
        .sheet(isPresented: $showTrackingPriming) {
            PermissionPrimingView(
                systemImage: "hand.raised.circle.fill",
                title: "att.priming.title",
                message: "att.priming.message",
                primaryButtonTitle: "att.priming.continue",
                onContinue: {
                    didPrimeTracking = true
                    showTrackingPriming = false
                    Task { await TrackingAuthorization.requestIfNeeded() }
                }
            )
        }
        .fullScreenCover(item: $matchObserver.newMatch) { row in
            MatchModalView(
                row: row,
                onSendMessage: {
                    matchObserver.dismiss()
                    if let matchId = row.match.id {
                        deepLinkRouter.openChat(matchId: matchId)
                        selectedTab = .chat
                    }
                },
                onKeepSwiping: { matchObserver.dismiss() }
            )
        }
    }

    /// Presents the ATT priming once, only after notifications have been handled,
    /// so the two system prompts don't stack on first launch.
    private func maybePrimeTracking() {
        guard !didPrimeTracking, !TrackingAuthorization.isDetermined else { return }
        showTrackingPriming = true
    }

    @ViewBuilder
    private var swipeTab: some View {
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
}
