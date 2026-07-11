import Foundation

protocol SwipeServicing {
    /// Records a swipe. The `onSwipeCreated` Cloud Function (Milestone 4) reacts
    /// to this write to detect mutual matches.
    func recordSwipe(_ swipe: Swipe) async throws

    /// Target pet ids the user has already swiped on, so they're excluded from
    /// the deck.
    func fetchSwipedTargetPetIds(swiperUserId: String) async throws -> Set<String>

    /// Pet ids that have already **superliked** the given pet — used to float
    /// those cards to the top of the deck with a Superlike badge (§3).
    func fetchIncomingSuperlikerPetIds(targetPetId: String) async throws -> Set<String>

    /// Pet ids that have liked/superliked any of the user's pets — backs the
    /// Plus-only "who liked you" list (§3, Likes tab).
    func fetchIncomingLikerPetIds(targetOwnerId: String) async throws -> [String]
}
