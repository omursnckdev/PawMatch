import Kingfisher
import SwiftUI

/// "It's a Match!" modal shown when a mutual match forms (§4).
struct MatchModalView: View {
    let row: MatchRow
    let onSendMessage: () -> Void
    let onKeepSwiping: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("match.modal.title")
                .font(.pawHeading(34))
                .foregroundStyle(Color.pawOrange)

            Text(String(format: String(localized: "match.modal.subtitle"), row.otherPet.name))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let urlString = row.otherPet.photoUrls.first, let url = URL(string: urlString) {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 180, height: 180)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.pawOrange, lineWidth: 3))
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onSendMessage) {
                    Text("match.modal.sendMessage")
                }
                .buttonStyle(PrimaryButtonStyle())

                Button("match.modal.keepSwiping", action: onKeepSwiping)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
