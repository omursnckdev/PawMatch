import Foundation

protocol UserServicing {
    /// Fetches the `users/{uid}` document, or `nil` if it doesn't exist yet.
    func fetchUser(uid: String) async throws -> AppUser?

    /// Creates the `users/{uid}` document on first sign-in. No-ops if it already exists.
    func createUserIfNeeded(uid: String, displayName: String, email: String?, authProvider: AppUser.AuthProvider) async throws

    /// Records the user's 18+ self-attestation.
    func confirmAge(uid: String) async throws

    /// Persists the client-managed daily swipe counters (§7 item 6 — the daily
    /// reset is handled client-side, not by a scheduled function).
    func updateSwipeCounters(uid: String, swipeCount: Int, superlikeCount: Int, lastResetDate: Date) async throws

    /// Adds or removes another user from the signed-in user's block list (§10.5).
    func setBlocked(uid: String, otherUserId: String, isBlocked: Bool) async throws

    /// Records which chat the user is actively viewing so the message push can be
    /// suppressed for that conversation (§7 item 3). Pass `nil` on leaving.
    func setActiveChat(uid: String, matchId: String?) async throws

    /// Stores the device's current FCM token so Cloud Functions can push to it.
    func updateFCMToken(uid: String, token: String) async throws
}
