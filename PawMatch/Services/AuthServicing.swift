import Foundation

/// Result of any successful sign-in/sign-up, regardless of provider.
struct AuthResult: Equatable {
    let uid: String
    let isNewUser: Bool
    let displayName: String?
    let email: String?
}

enum AuthServiceError: LocalizedError {
    case invalidAppleCredential
    case notSignedIn
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            return "Apple sign-in didn't return the information we need. Please try again."
        case .notSignedIn:
            return "You're not signed in."
        case .underlying(let message):
            return message
        }
    }
}

/// Wraps Firebase Auth so ViewModels can be unit tested against a mock.
protocol AuthServicing {
    var currentUserId: String? { get }

    /// Emits the current uid immediately, then again on every auth state change.
    /// Emits `nil` when signed out.
    func authStateStream() -> AsyncStream<String?>

    func signUp(email: String, password: String) async throws -> AuthResult
    func signIn(email: String, password: String) async throws -> AuthResult
    func signInWithApple(idTokenString: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthResult
    func signOut() throws
}
