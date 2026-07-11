import SwiftUI

/// Central place the notification layer drops a deep-link target so SwiftUI can
/// react to it. Tapping a "new match"/"new message" push sets `pendingMatchId`,
/// which `MainTabView` observes to switch to Chat and open that conversation
/// (§7 item 3 — notifications deep-link straight into the chat).
@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()

    @Published var pendingMatchId: String?

    func openChat(matchId: String) {
        pendingMatchId = matchId
    }

    func clear() {
        pendingMatchId = nil
    }
}
