import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            switch authViewModel.sessionState {
            case .loading:
                SplashView()
            case .signedOut:
                AuthView(viewModel: authViewModel)
            case .needsAgeConfirmation:
                AgeConfirmationView(viewModel: authViewModel)
            case .ready:
                ComingSoonView(viewModel: authViewModel)
            }
        }
        .animation(.default, value: authViewModel.sessionState)
    }
}

#Preview {
    RootView()
}
