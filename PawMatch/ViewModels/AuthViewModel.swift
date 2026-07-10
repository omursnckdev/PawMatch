import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    enum SessionState: Equatable {
        case loading
        case signedOut
        case needsAgeConfirmation
        case ready
    }

    @Published private(set) var sessionState: SessionState = .loading
    @Published var email = ""
    @Published var password = ""
    @Published var isSignUpMode = true
    @Published var isLoading = false
    @Published var errorMessage: String?

    var canSubmitEmailForm: Bool {
        email.contains("@") && password.count >= 6 && !isLoading
    }

    private let authService: AuthServicing
    private let userService: UserServicing
    private let analytics: AnalyticsServicing
    private let appleSignInCoordinator: AppleSignInCoordinating
    private var authStateTask: Task<Void, Never>?

    init(
        authService: AuthServicing = AuthService.shared,
        userService: UserServicing = UserService.shared,
        analytics: AnalyticsServicing = AnalyticsService.shared,
        appleSignInCoordinator: AppleSignInCoordinating = AppleSignInCoordinator()
    ) {
        self.authService = authService
        self.userService = userService
        self.analytics = analytics
        self.appleSignInCoordinator = appleSignInCoordinator
        observeAuthState()
    }

    deinit {
        authStateTask?.cancel()
    }

    private func observeAuthState() {
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await uid in self.authService.authStateStream() {
                if let uid {
                    await self.refreshSession(uid: uid)
                } else {
                    self.sessionState = .signedOut
                }
            }
        }
    }

    func toggleMode() {
        isSignUpMode.toggle()
        errorMessage = nil
    }

    func submitEmailForm() async {
        guard canSubmitEmailForm else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = isSignUpMode
                ? try await authService.signUp(email: email, password: password)
                : try await authService.signIn(email: email, password: password)
            try await finishSignIn(result: result, provider: .email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithApple() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let payload = try await appleSignInCoordinator.signIn()
            let result = try await authService.signInWithApple(
                idTokenString: payload.idTokenString,
                rawNonce: payload.rawNonce,
                fullName: payload.fullName
            )
            try await finishSignIn(result: result, provider: .apple)
        } catch let error as AppleSignInError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmAge() async {
        guard let uid = authService.currentUserId else { return }
        do {
            try await userService.confirmAge(uid: uid)
            sessionState = .ready
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try authService.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishSignIn(result: AuthResult, provider: AppUser.AuthProvider) async throws {
        try await userService.createUserIfNeeded(
            uid: result.uid,
            displayName: result.displayName ?? "Pet Parent",
            email: result.email,
            authProvider: provider
        )
        if result.isNewUser {
            analytics.log(.signUpCompleted(method: provider.rawValue))
        }
        await refreshSession(uid: result.uid)
    }

    private func refreshSession(uid: String) async {
        do {
            guard let user = try await userService.fetchUser(uid: uid) else {
                sessionState = .needsAgeConfirmation
                return
            }
            sessionState = user.isAgeConfirmed ? .ready : .needsAgeConfirmation
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
