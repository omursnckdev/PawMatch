import GoogleMobileAds
import Foundation

/// Loads a Google native ad for the swipe deck's every-10th-card slot (§8,
/// AdMob). Ads are non-personalized unless the user grants App Tracking
/// Transparency (§10.4) — pass `trackingAuthorized` from the ATT status.
@MainActor
final class AdManager: NSObject, ObservableObject {
    @Published private(set) var nativeAd: NativeAd?

    private var adLoader: AdLoader?
    private let adUnitID: String

    /// Google's public test native ad unit id; overridden by the real id from
    /// Secrets/Info.plist in release builds (switch to production only right
    /// before submission, §8).
    private static let testNativeAdUnitID = "ca-app-pub-3940256099942544/3986624511"

    init(adUnitID: String = AdManager.configuredAdUnitID) {
        self.adUnitID = adUnitID
        super.init()
    }

    static var configuredAdUnitID: String {
        #if DEBUG
        return testNativeAdUnitID
        #else
        return (Bundle.main.object(forInfoDictionaryKey: "ADMOB_NATIVE_AD_UNIT_ID") as? String) ?? testNativeAdUnitID
        #endif
    }

    func loadAd(trackingAuthorized: Bool) {
        let request = Request()
        if !trackingAuthorized {
            let extras = Extras()
            extras.additionalParameters = ["npa": "1"]
            request.register(extras)
        }

        let loader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: nil,
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        loader.load(request)
        adLoader = loader
    }

    func clear() {
        nativeAd = nil
    }
}

extension AdManager: NativeAdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        self.nativeAd = nativeAd
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        self.nativeAd = nil
    }
}
