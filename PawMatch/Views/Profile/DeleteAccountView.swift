import SwiftUI

/// Delete Account flow (§10.5). Requires an explicit acknowledgment, then calls
/// the Cloud Function that actually deletes the user's data.
struct DeleteAccountView: View {
    let onDeleted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DeleteAccountViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)

                Text("deleteAccount.warning.title")
                    .font(.pawHeading(22))

                Text("deleteAccount.warning.message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Toggle(isOn: $viewModel.acknowledged) {
                    Text("deleteAccount.confirm.checkbox").font(.subheadline)
                }

                Button {
                    Task {
                        if await viewModel.deleteAccount() { onDeleted() }
                    }
                } label: {
                    if viewModel.isDeleting {
                        ProgressView().tint(.white)
                    } else {
                        Text("deleteAccount.button")
                    }
                }
                .buttonStyle(DestructiveButtonStyle(isDisabled: !viewModel.canDelete))
                .disabled(!viewModel.canDelete)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("deleteAccount.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel") { dismiss() }
                        .disabled(viewModel.isDeleting)
                }
            }
            .interactiveDismissDisabled(viewModel.isDeleting)
        }
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    var isDisabled = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.pawHeading(17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isDisabled ? Color.red.opacity(0.4) : Color.red)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}
