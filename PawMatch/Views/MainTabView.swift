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
    @State private var activePriming: Priming?

    enum Tab: Hashable {
        case swipe, matches, chat, likes, profile
    }

    /// First-run permission priming steps, presented one at a time through a
    /// single sheet so SwiftUI never has to juggle two `.sheet` modifiers.
    private enum Priming: Identifiable {
        case notifications, tracking
        var id: Int { hashValue }
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
            advancePriming()
        }
        .onChange(of: deepLinkRouter.pendingMatchId) { _, matchId in
            if matchId != nil { selectedTab = .chat }
        }
        .sheet(item: $activePriming, onDismiss: advancePriming) { priming in
            primingSheet(priming)
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

    /// Presents the next outstanding first-run priming step. Called on appear and
    /// after each priming sheet dismisses, so notifications and ATT are shown in
    /// sequence rather than stacked.
    private func advancePriming() {
        if !didPrimeNotifications {
            activePriming = .notifications
        } else if !didPrimeTracking && !TrackingAuthorization.isDetermined {
            activePriming = .tracking
        } else {
            activePriming = nil
        }
    }

    @ViewBuilder
    private func primingSheet(_ priming: Priming) -> some View {
        switch priming {
        case .notifications:
            PermissionPrimingView(
                systemImage: "bell.badge.fill",
                title: "notif.priming.title",
                message: "notif.priming.message",
                primaryButtonTitle: "notif.priming.enable",
                onContinue: {
                    didPrimeNotifications = true
                    activePriming = nil
                    Task { await NotificationService.shared.requestAuthorization() }
                },
                onSkip: {
                    didPrimeNotifications = true
                    activePriming = nil
                }
            )
        case .tracking:
            PermissionPrimingView(
                systemImage: "hand.raised.circle.fill",
                title: "att.priming.title",
                message: "att.priming.message",
                primaryButtonTitle: "att.priming.continue",
                onContinue: {
                    didPrimeTracking = true
                    activePriming = nil
                    Task { await TrackingAuthorization.requestIfNeeded() }
                }
            )
        }
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
