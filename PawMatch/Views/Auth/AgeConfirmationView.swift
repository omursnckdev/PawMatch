import SwiftUI

/// First-run 18+ gate (§10.6). Community Guidelines / Terms acknowledgment is
/// added alongside this in Milestone 6 once those pages exist (§10.8, §13).
struct AgeConfirmationView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var isConfirmed = false
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pawOrange)

            Text("age.title")
                .font(.pawHeading(24))

            Text("age.body")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Toggle(isOn: $isConfirmed) {
                Text("age.confirm")
                    .font(.subheadline)
            }
            .toggleStyle(.switch)

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
            .buttonStyle(PrimaryButtonStyle(isDisabled: !isConfirmed))
            .disabled(!isConfirmed || isSubmitting)

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
}

#Preview {
    AgeConfirmationView(viewModel: AuthViewModel())
}
