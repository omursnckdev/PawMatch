import RevenueCat
import Foundation

/// Wraps RevenueCat / StoreKit 2 (§8). Note: the **source of truth** for
/// entitlement is the Firestore `isPremium` field set by `revenueCatWebhook`
/// (see `EntitlementManager`); this SDK layer drives the purchase UI and gives
/// an immediate optimistic signal while the webhook catches up.
final class PurchaseService: PurchasesServicing {
    static let shared = PurchaseService()

    private var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_PUBLIC_API_KEY") as? String) ?? ""
    }

    func configure() {
        guard !apiKey.isEmpty else {
            assertionFailure("REVENUECAT_PUBLIC_API_KEY missing from Secrets.xcconfig")
            return
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    }

    func logIn(uid: String) async {
        _ = try? await Purchases.shared.logIn(uid)
    }

    func logOut() async {
        _ = try? await Purchases.shared.logOut()
    }

    func currentOfferings() async throws -> Offering? {
        try await Purchases.shared.offerings().current
    }

    func purchase(_ package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)
        return result.customerInfo.entitlements[Entitlement.plus]?.isActive == true
    }

    func restorePurchases() async throws -> Bool {
        let info = try await Purchases.shared.restorePurchases()
        return info.entitlements[Entitlement.plus]?.isActive == true
    }

    func isPlusActive() async -> Bool {
        guard let info = try? await Purchases.shared.customerInfo() else { return false }
        return info.entitlements[Entitlement.plus]?.isActive == true
    }
}
