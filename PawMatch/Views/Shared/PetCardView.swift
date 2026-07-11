import Kingfisher
import SwiftUI

/// The single reusable pet card (§9), used identically in the swipe deck, the
/// "It's a Match!" modal, and profile detail. Distance and the Superlike badge
/// are optional overlays so the same component works in contexts where they
/// don't apply (e.g. previewing your own pet during setup).
struct PetCardView: View {
    let pet: Pet
    var distanceKm: Double? = nil
    var isSuperliked: Bool = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            photo
            gradientScrim
            overlayContent
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if isSuperliked {
                superlikeBadge
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var photo: some View {
        if let urlString = pet.photoUrls.first, let url = URL(string: urlString) {
            KFImage(url)
                .resizable()
                .fade(duration: 0.2)
                .placeholder { placeholder }
                .scaledToFill()
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.secondarySystemBackground)
            Image(systemName: "pawprint.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
        }
    }

    private var gradientScrim: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.65)],
            startPoint: .center,
            endPoint: .bottom
        )
    }

    private var overlayContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(pet.name)
                    .font(.pawHeading(26))
                Text("\(pet.age)")
                    .font(.pawHeading(22, weight: .regular))
            }
            .foregroundStyle(.white)

            Text(pet.breed)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            if let distanceKm {
                Label(distanceText(distanceKm), systemImage: "location.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }

            purposeChips
        }
        .padding(16)
    }

    private var purposeChips: some View {
        HStack(spacing: 6) {
            ForEach(pet.purposes, id: \.self) { purpose in
                Text(purpose == .playdate ? "purpose.playdate" : "purpose.breeding")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .padding(.top, 2)
    }

    private var superlikeBadge: some View {
        Image(systemName: "star.fill")
            .font(.headline)
            .foregroundStyle(.white)
            .padding(10)
            .background(Color.blue, in: Circle())
            .padding(12)
            .accessibilityLabel(Text("badge.superliked"))
    }

    private func distanceText(_ km: Double) -> String {
        if km < 1 {
            return String(localized: "distance.lessThanOneKm")
        }
        return String(format: String(localized: "distance.kmAway"), Int(km.rounded()))
    }
}
