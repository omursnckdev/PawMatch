import Foundation

protocol UserServicing {
    /// Fetches the `users/{uid}` document, or `nil` if it doesn't exist yet.
    func fetchUser(uid: String) async throws -> AppUser?

    /// Creates the `users/{uid}` document on first sign-in. No-ops if it already exists.
    func createUserIfNeeded(uid: String, displayName: String, email: String?, authProvider: AppUser.AuthProvider) async throws

    /// Records the user's 18+ self-attestation.
    func confirmAge(uid: String) async throws
}
