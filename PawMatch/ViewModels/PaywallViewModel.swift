import RevenueCat
import Foundation

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published private(set) var packages: [Package] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?
    @Published var didPurchase = false

    let source: PaywallSource

    private let purchases: PurchasesServicing
    private let entitlements: EntitlementManager
    private let analytics: AnalyticsServicing

    init(
        source: PaywallSource,
        purchases: PurchasesServicing = PurchaseService.shared,
        entitlements: EntitlementManager = .shared,
        analytics: AnalyticsServicing = AnalyticsService.shared
    ) {
        self.source = source
        self.purchases = purchases
        self.entitlements = entitlements
        self.analytics = analytics
    }

    func onAppear() async {
        analytics.log(.paywallViewed(source: source.rawValue))
        await loadOfferings()
    }

    func loadOfferings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let offering = try await purchases.currentOfferings()
            packages = offering?.availablePackages ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchase(_ package: Package) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let active = try await purchases.purchase(package)
            if active {
                entitlements.applyOptimisticPremium()
                analytics.log(.paywallPurchaseCompleted(productId: package.storeProduct.productIdentifier))
                didPurchase = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let active = try await purchases.restorePurchases()
            if active {
                entitlements.applyOptimisticPremium()
                didPurchase = true
            } else {
                errorMessage = String(localized: "paywall.restore.none")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissed() {
        analytics.log(.paywallDismissed)
    }
}
