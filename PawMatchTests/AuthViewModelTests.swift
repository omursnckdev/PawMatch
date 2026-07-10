import XCTest
@testable import PawMatch

@MainActor
final class AuthViewModelTests: XCTestCase {
    private var authService: MockAuthService!
    private var userService: MockUserService!
    private var analytics: MockAnalyticsService!
    private var appleCoordinator: MockAppleSignInCoordinator!
    private var viewModel: AuthViewModel!

    override func setUp() async throws {
        authService = MockAuthService()
        userService = MockUserService()
        analytics = MockAnalyticsService()
        appleCoordinator = MockAppleSignInCoordinator()
        viewModel = AuthViewModel(
            authService: authService,
            userService: userService,
            analytics: analytics,
            appleSignInCoordinator: appleCoordinator
        )
        // Let the initial authStateStream emission (nil) land before asserting state.
        try await Task.sleep(nanoseconds: 10_000_000)
    }

    func testCanSubmitEmailFormRequiresValidEmailAndPassword() {
        viewModel.email = "not-an-email"
        viewModel.password = "123456"
        XCTAssertFalse(viewModel.canSubmitEmailForm)

        viewModel.email = "user@example.com"
        viewModel.password = "12345"
        XCTAssertFalse(viewModel.canSubmitEmailForm)

        viewModel.password = "123456"
        XCTAssertTrue(viewModel.canSubmitEmailForm)
    }

    func testSignUpCreatesUserAndRoutesToAgeConfirmation() async {
        authService.signUpResult = .success(AuthResult(uid: "uid-1", isNewUser: true, displayName: "Jane", email: "jane@example.com"))
        viewModel.isSignUpMode = true
        viewModel.email = "jane@example.com"
        viewModel.password = "123456"

        await viewModel.submitEmailForm()

        XCTAssertEqual(userService.createUserIfNeededCallCount, 1)
        XCTAssertEqual(analytics.loggedEventNames, ["sign_up_completed"])
        XCTAssertEqual(viewModel.sessionState, .needsAgeConfirmation)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testSignInFailurePopulatesErrorMessage() async {
        authService.signInResult = .failure(AuthServiceError.underlying("Wrong password"))
        viewModel.isSignUpMode = false
        viewModel.email = "jane@example.com"
        viewModel.password = "123456"

        await viewModel.submitEmailForm()

        XCTAssertEqual(viewModel.errorMessage, "Wrong password")
        XCTAssertEqual(viewModel.sessionState, .signedOut)
    }

    func testConfirmAgeMovesSessionToReady() async {
        authService.signUpResult = .success(AuthResult(uid: "uid-2", isNewUser: true, displayName: "Sam", email: "sam@example.com"))
        viewModel.isSignUpMode = true
        viewModel.email = "sam@example.com"
        viewModel.password = "123456"
        await viewModel.submitEmailForm()
        XCTAssertEqual(viewModel.sessionState, .needsAgeConfirmation)

        authService.currentUserId = "uid-2"
        await viewModel.confirmAge()

        XCTAssertEqual(userService.confirmAgeCallCount, 1)
        XCTAssertEqual(viewModel.sessionState, .ready)
    }

    func testAppleSignInCancellationLeavesErrorMessageNil() async {
        appleCoordinator.result = .failure(AppleSignInError.userCancelled)

        await viewModel.signInWithApple()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.sessionState, .signedOut)
    }

    func testAppleSignInSuccessCreatesUser() async {
        appleCoordinator.result = .success(AppleSignInPayload(idTokenString: "token", rawNonce: "nonce", fullName: nil))
        authService.signInWithAppleResult = .success(AuthResult(uid: "uid-3", isNewUser: true, displayName: "Alex", email: nil))

        await viewModel.signInWithApple()

        XCTAssertEqual(userService.createUserIfNeededCallCount, 1)
        XCTAssertEqual(viewModel.sessionState, .needsAgeConfirmation)
    }

    func testSignOutSurfacesError() {
        authService.signOutError = AuthServiceError.underlying("Network unavailable")

        viewModel.signOut()

        XCTAssertEqual(viewModel.errorMessage, "Network unavailable")
    }
}
