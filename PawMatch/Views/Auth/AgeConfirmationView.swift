import SwiftUI

/// First-run 18+ gate (§10.6) plus the Terms / Community Guidelines
/// acknowledgment required at signup (§10.8, §13).
struct AgeConfirmationView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var isAgeConfirmed = false
    @State private var agreedToPolicies = false
    @State private var isSubmitting = false

    private var canContinue: Bool { isAgeConfirmed && agreedToPolicies && !isSubmitting }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pawOrange)

            Text("age.title")
                .font(.pawHeading(24))

            Text("age.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Toggle(isOn: $isAgeConfirmed) {
                Text("age.confirm").font(.subheadline)
            }
            .toggleStyle(.switch)

            Toggle(isOn: $agreedToPolicies) {
                Text("age.agreePolicies").font(.subheadline)
            }
            .toggleStyle(.switch)

            legalLinks

            Button {
                Task {
                    isSubmitting = true
                    await viewModel.confirmAge()
                    isSubmitting = false
                }
            } label: {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("age.continue")
                }
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: !canContinue))
            .disabled(!canContinue)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
    }

    private var legalLinks: some View {
        HStack(spacing: 14) {
            Link("legal.terms", destination: LegalLinks.termsOfService)
            Link("legal.privacy", destination: LegalLinks.privacyPolicy)
            Link("legal.community", destination: LegalLinks.communityGuidelines)
        }
        .font(.caption)
    }
}

#Preview {
    AgeConfirmationView(viewModel: AuthViewModel())
}
