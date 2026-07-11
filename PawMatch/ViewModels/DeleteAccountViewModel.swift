import Foundation

@MainActor
final class DeleteAccountViewModel: ObservableObject {
    @Published var acknowledged = false
    @Published private(set) var isDeleting = false
    @Published var errorMessage: String?

    private let accountService: AccountServicing

    init(accountService: AccountServicing = AccountService.shared) {
        self.accountService = accountService
    }

    var canDelete: Bool { acknowledged && !isDeleting }

    /// Returns true on success so the view can dismiss and sign out.
    func deleteAccount() async -> Bool {
        guard canDelete else { return false }
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await accountService.deleteAccount()
            return true
        } catch {
            errorMessage = String(localized: "deleteAccount.error")
            return false
        }
    }
}
