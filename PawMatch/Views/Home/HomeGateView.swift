import SwiftUI

/// Post-auth landing point. Fetches the user's pets and routes:
///   0 pets  → first-run pet profile setup
///   ≥1 pet  → main experience (Manage Pets placeholder until Milestone 3+)
///
/// This is what satisfies Milestone 2's acceptance criterion: "a new user with
/// 0 pets is routed into profile setup; profile persists across relaunch."
struct HomeGateView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                loadingState
            case .needsFirstPet:
                PetProfileSetupView(
                    viewModel: PetProfileViewModel(),
                    onComplete: { _ in Task { await viewModel.load() } }
                )
            case .ready(let pets):
                MainTabView(
                    pets: pets,
                    homeViewModel: viewModel,
                    onSignOut: { authViewModel.signOut() }
                )
            case .error(let message):
                errorState(message)
            }
        }
        .task {
            await startEntitlements()
            await viewModel.load()
        }
    }

    /// Associates RevenueCat with the Firebase uid and begins listening to the
    /// authoritative `isPremium` field (§8).
    private func startEntitlements() async {
        guard let uid = AuthService.shared.currentUserId else { return }
        EntitlementManager.shared.start(uid: uid)
        await PurchaseService.shared.logIn(uid: uid)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("home.loading").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("common.retry") { Task { await viewModel.load() } }
                .buttonStyle(PrimaryButtonStyle())
                .fixedSize()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
