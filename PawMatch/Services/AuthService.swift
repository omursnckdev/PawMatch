import FirebaseAuth
import Foundation

/// Concrete `AuthServicing` backed by Firebase Auth.
final class AuthService: AuthServicing {
    static let shared = AuthService()

    private let auth: Auth

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
    }

    var currentUserId: String? {
        auth.currentUser?.uid
    }

    func authStateStream() -> AsyncStream<String?> {
        AsyncStream { continuation in
            continuation.yield(self.auth.currentUser?.uid)
            let handle = self.auth.addStateDidChangeListener { _, user in
                continuation.yield(user?.uid)
            }
            continuation.onTermination = { [auth] _ in
                auth.removeStateDidChangeListener(handle)
            }
        }
    }

    func signUp(email: String, password: String) async throws -> AuthResult {
        let result = try await auth.createUser(withEmail: email, password: password)
        return AuthResult(
            uid: result.user.uid,
            isNewUser: result.additionalUserInfo?.isNewUser ?? true,
            displayName: result.user.displayName,
            email: result.user.email
        )
    }

    func signIn(email: String, password: String) async throws -> AuthResult {
        let result = try await auth.signIn(withEmail: email, password: password)
        return AuthResult(
            uid: result.user.uid,
            isNewUser: result.additionalUserInfo?.isNewUser ?? false,
            displayName: result.user.displayName,
            email: result.user.email
        )
    }

    func signInWithApple(idTokenString: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthResult {
        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idTokenString,
            rawNonce: rawNonce
        )
        let result = try await auth.signIn(with: credential)

        let displayName: String?
        if let fullName, !(fullName.givenName ?? "").isEmpty {
            displayName = PersonNameComponentsFormatter().string(from: fullName)
        } else {
            displayName = result.user.displayName
        }

        return AuthResult(
            uid: result.user.uid,
            isNewUser: result.additionalUserInfo?.isNewUser ?? false,
            displayName: displayName,
            email: result.user.email
        )
    }

    func signOut() throws {
        try auth.signOut()
    }
}
