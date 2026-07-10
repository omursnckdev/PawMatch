import FirebaseFirestore
@testable import PawMatch

final class MockAuthService: AuthServicing {
    var currentUserId: String?
    var signUpResult: Result<AuthResult, Error> = .failure(AuthServiceError.notSignedIn)
    var signInResult: Result<AuthResult, Error> = .failure(AuthServiceError.notSignedIn)
    var signInWithAppleResult: Result<AuthResult, Error> = .failure(AuthServiceError.notSignedIn)
    var signOutError: Error?
    private var continuation: AsyncStream<String?>.Continuation?

    func authStateStream() -> AsyncStream<String?> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.currentUserId)
        }
    }

    func emitAuthState(_ uid: String?) {
        currentUserId = uid
        continuation?.yield(uid)
    }

    func signUp(email: String, password: String) async throws -> AuthResult {
        try signUpResult.get()
    }

    func signIn(email: String, password: String) async throws -> AuthResult {
        try signInResult.get()
    }

    func signInWithApple(idTokenString: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthResult {
        try signInWithAppleResult.get()
    }

    func signOut() throws {
        if let signOutError {
            throw signOutError
        }
        emitAuthState(nil)
    }
}

final class MockUserService: UserServicing {
    var storedUsers: [String: AppUser] = [:]
    private(set) var createUserIfNeededCallCount = 0
    private(set) var confirmAgeCallCount = 0

    func fetchUser(uid: String) async throws -> AppUser? {
        storedUsers[uid]
    }

    func createUserIfNeeded(uid: String, displayName: String, email: String?, authProvider: AppUser.AuthProvider) async throws {
        createUserIfNeededCallCount += 1
        guard storedUsers[uid] == nil else { return }
        storedUsers[uid] = AppUser(
            id: uid,
            displayName: displayName,
            email: email,
            authProvider: authProvider,
            isPremium: false,
            billingIssue: false,
            dailySwipeCount: 0,
            lastSwipeResetDate: Timestamp(date: Date()),
            fcmToken: nil,
            blockedUserIds: [],
            isAgeConfirmed: false,
            createdAt: Timestamp(date: Date())
        )
    }

    func confirmAge(uid: String) async throws {
        confirmAgeCallCount += 1
        storedUsers[uid]?.isAgeConfirmed = true
    }
}

final class MockAnalyticsService: AnalyticsServicing {
    private(set) var loggedEventNames: [String] = []

    func log(_ event: AnalyticsEvent) {
        loggedEventNames.append(event.name)
    }
}

final class MockAppleSignInCoordinator: AppleSignInCoordinating {
    var result: Result<AppleSignInPayload, Error> = .failure(AppleSignInError.userCancelled)

    func signIn() async throws -> AppleSignInPayload {
        try result.get()
    }
}
