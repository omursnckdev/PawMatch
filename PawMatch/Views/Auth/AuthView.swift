import SwiftUI

struct AuthView: View {
    @ObservedObject var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    private enum Field {
        case email, password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                appleSignInButton

                dividerRow

                emailForm

                toggleModeButton

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                // Terms & Privacy must be reachable without an account (§13).
                HStack(spacing: 14) {
                    Link("legal.terms", destination: LegalLinks.termsOfService)
                    Link("legal.privacy", destination: LegalLinks.privacyPolicy)
                }
                .font(.caption)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
        .scrollDismissesKeyboard(.interactively)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "pawprint.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pawOrange)
            Text(viewModel.isSignUpMode ? String(localized: "auth.signup.title") : String(localized: "auth.login.title"))
                .font(.pawHeading(24))
            Text("auth.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
    }

    private var appleSignInButton: some View {
        Button {
            Task { await viewModel.signInWithApple() }
        } label: {
            HStack {
                Image(systemName: "apple.logo")
                Text("auth.signInWithApple")
                    .font(.pawHeading(16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(viewModel.isLoading)
    }

    private var dividerRow: some View {
        HStack {
            Rectangle().frame(height: 1).foregroundStyle(.tertiary)
            Text("auth.or").font(.footnote).foregroundStyle(.secondary)
            Rectangle().frame(height: 1).foregroundStyle(.tertiary)
        }
    }

    private var emailForm: some View {
        VStack(spacing: 12) {
            TextField(String(localized: "auth.email.placeholder"), text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            SecureField(String(localized: "auth.password.placeholder"), text: $viewModel.password)
                .textContentType(viewModel.isSignUpMode ? .newPassword : .password)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { Task { await viewModel.submitEmailForm() } }
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                Task { await viewModel.submitEmailForm() }
            } label: {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(viewModel.isSignUpMode ? String(localized: "auth.signUp.button") : String(localized: "auth.login.button"))
                }
            }
            .buttonStyle(PrimaryButtonStyle(isDisabled: !viewModel.canSubmitEmailForm))
            .disabled(!viewModel.canSubmitEmailForm)
        }
    }

    private var toggleModeButton: some View {
        Button {
            viewModel.toggleMode()
        } label: {
            Text(viewModel.isSignUpMode ? String(localized: "auth.toggle.toLogin") : String(localized: "auth.toggle.toSignUp"))
                .font(.subheadline)
        }
    }
}

#Preview {
    AuthView(viewModel: AuthViewModel())
}
