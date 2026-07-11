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
}
