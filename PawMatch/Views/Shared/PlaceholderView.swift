import SwiftUI

/// Generic centered empty/coming-soon state used by tabs and lists that aren't
/// built out yet, so no screen ever renders blank (§9).
struct PlaceholderView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(Color.pawOrange.opacity(0.8))
            Text(title)
                .font(.pawHeading(20))
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
