import FirebaseFunctions
import Foundation

/// Calls the `onAccountDeletionRequested` Cloud Function, which actually removes
/// the user's Firestore/Storage data and auth record (§10.5 — Delete Account
/// must delete data, not just sign out).
final class AccountService: AccountServicing {
    static let shared = AccountService()

    private let functions: Functions
    private let authService: AuthServicing

    init(functions: Functions = Functions.functions(), authService: AuthServicing = AuthService.shared) {
        self.functions = functions
        self.authService = authService
    }

    func deleteAccount() async throws {
        _ = try await functions.httpsCallable("onAccountDeletionRequested").call()
        // The auth record is deleted server-side; make sure the client session
        // ends too so the app returns to the signed-out state.
        try? authService.signOut()
    }
}
