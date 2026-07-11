import SwiftUI

/// PawMatch Plus paywall. Milestone 3 ships this as a benefits screen with the
/// purchase button disabled — the RevenueCat purchase flow, real pricing, and
/// subscription-terms disclosure are wired in Milestone 5 (§8, §13). It already
/// logs the analytics funnel events so drop-off is measurable from now on.
struct PaywallView: View {
    let source: PaywallSource
    let onDismiss: () -> Void

    private let benefits: [(icon: String, title: LocalizedStringKey)] = [
        ("infinity", "paywall.benefit.unlimited"),
        ("pawprint.fill", "paywall.benefit.multiPet"),
        ("slider.horizontal.3", "paywall.benefit.filters"),
        ("arrow.uturn.backward", "paywall.benefit.rewind"),
        ("heart.fill", "paywall.benefit.whoLiked"),
        ("bolt.fill", "paywall.benefit.boost"),
        ("nosign", "paywall.benefit.noAds")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.pawOrange)

                Text("paywall.title")
                    .font(.pawHeading(26))
                Text(headline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(benefits, id: \.icon) { benefit in
                        HStack(spacing: 12) {
                            Image(systemName: benefit.icon)
                                .foregroundStyle(Color.pawOrange)
                                .frame(width: 28)
                            Text(benefit.title)
                                .font(.body)
                            Spacer()
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    // Purchase is wired in Milestone 5.
                } label: {
                    Text("paywall.subscribe.comingSoon")
                }
                .buttonStyle(PrimaryButtonStyle(isDisabled: true))
                .disabled(true)

                Button("paywall.maybeLater", action: onDismiss)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("paywall.terms.placeholder")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
        .background(Color(.systemBackground))
    }

    private var headline: LocalizedStringKey {
        switch source {
        case .swipeLimit: return "paywall.headline.swipeLimit"
        case .superlikeLimit: return "paywall.headline.superlikeLimit"
        case .secondPet: return "paywall.headline.secondPet"
        case .likesTab: return "paywall.headline.likesTab"
        case .rewind: return "paywall.headline.rewind"
        case .boost: return "paywall.headline.boost"
        }
    }
}

#Preview {
    PaywallView(source: .swipeLimit, onDismiss: {})
}
