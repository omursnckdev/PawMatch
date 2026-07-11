import Foundation

protocol AccountServicing {
    /// Invokes the `onAccountDeletionRequested` callable, which deletes the
    /// user's data server-side, then signs out locally (§10.5).
    func deleteAccount() async throws
}
