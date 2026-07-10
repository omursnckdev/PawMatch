import SwiftUI

/// Placeholder landing spot until Milestone 2 (Pet Profiles) builds the real
/// onboarding flow and Milestone 3+ builds the main tab bar. Keeps the app from
/// dead-ending after sign-in while those milestones are in progress.
struct ComingSoonView: View {
    @ObservedObject var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.pawOrange)
            Text("You're signed in!")
                .font(.pawHeading(22))
            Text("Pet profile setup and swiping are coming in the next milestones.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Sign Out") {
                viewModel.signOut()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 24)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ComingSoonView(viewModel: AuthViewModel())
}
