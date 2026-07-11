import RevenueCat

/// Entitlement identifier configured in the RevenueCat dashboard (§8).
enum Entitlement {
    static let plus = "plus"
}

protocol PurchasesServicing {
    /// Configures the RevenueCat SDK. Call once at launch.
    func configure()
    /// Associates purchases with the Firebase uid (call after sign-in).
    func logIn(uid: String) async
    func logOut() async

    func currentOfferings() async throws -> Offering?
    /// Returns whether the `plus` entitlement is active after the purchase.
    func purchase(_ package: Package) async throws -> Bool
    /// Returns whether the `plus` entitlement is active after restoring.
    func restorePurchases() async throws -> Bool
    /// True if the `plus` entitlement is currently active per the SDK cache.
    func isPlusActive() async -> Bool
}
