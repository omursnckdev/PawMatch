import GoogleMobileAds
import SwiftUI

/// Renders a Google native ad styled to match `PetCardView` so the every-10th
/// ad slot doesn't feel like a jarring banner (§8). Wraps `NativeAdView` (the
/// SDK requires its asset subviews to be wired to a `NativeAdView`).
struct NativeAdCardView: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        adView.layer.cornerRadius = 20
        adView.clipsToBounds = true
        adView.backgroundColor = UIColor.secondarySystemBackground

        let media = MediaView()
        media.translatesAutoresizingMaskIntoConstraints = false
        media.contentMode = .scaleAspectFill
        media.clipsToBounds = true

        let sponsored = makeLabel(text: "Sponsored", size: 12, weight: .semibold, color: .secondaryLabel)
        let headline = makeLabel(text: nil, size: 20, weight: .bold, color: .label)
        let body = makeLabel(text: nil, size: 14, weight: .regular, color: .secondaryLabel)

        let cta = UIButton(type: .system)
        cta.translatesAutoresizingMaskIntoConstraints = false
        cta.backgroundColor = UIColor(Color.pawOrange)
        cta.setTitleColor(.white, for: .normal)
        cta.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        cta.layer.cornerRadius = 12
        cta.isUserInteractionEnabled = false // the ad view handles taps

        let textStack = UIStackView(arrangedSubviews: [sponsored, headline, body, cta])
        textStack.axis = .vertical
        textStack.spacing = 6
        textStack.translatesAutoresizingMaskIntoConstraints = false

        adView.addSubview(media)
        adView.addSubview(textStack)

        NSLayoutConstraint.activate([
            media.topAnchor.constraint(equalTo: adView.topAnchor),
            media.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            media.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            media.heightAnchor.constraint(equalTo: adView.heightAnchor, multiplier: 0.6),

            textStack.topAnchor.constraint(equalTo: media.bottomAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 16),
            textStack.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -16),
            cta.heightAnchor.constraint(equalToConstant: 44),
        ])

        adView.mediaView = media
        adView.headlineView = headline
        adView.bodyView = body
        adView.callToActionView = cta

        return adView
    }

    func updateUIView(_ adView: NativeAdView, context: Context) {
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction ?? "Learn More", for: .normal)
        adView.mediaView?.mediaContent = nativeAd.mediaContent
        adView.nativeAd = nativeAd
    }

    private func makeLabel(text: String?, size: CGFloat, weight: UIFont.Weight, color: UIColor) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.numberOfLines = 2
        return label
    }
}
