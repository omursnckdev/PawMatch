import SwiftUI

/// Reusable "priming" screen (§9): a friendly icon + one-sentence benefit shown
/// immediately before a hard OS permission dialog (location, notifications, ATT)
/// so system prompts never fire cold on first launch.
struct PermissionPrimingView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryButtonTitle: LocalizedStringKey
    let onContinue: () -> Void
    var onSkip: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundStyle(Color.pawOrange)

            Text(title)
                .font(.pawHeading(22))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            Button(action: onContinue) {
                Text(primaryButtonTitle)
            }
            .buttonStyle(PrimaryButtonStyle())

            if let onSkip {
                Button("common.notNow", action: onSkip)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
    }
}

#Preview {
    PermissionPrimingView(
        systemImage: "location.fill",
        title: "See pets near you",
        message: "PawMatch uses your location to show nearby pets and how far away each one is.",
        primaryButtonTitle: "Enable Location",
        onContinue: {},
        onSkip: {}
    )
}
