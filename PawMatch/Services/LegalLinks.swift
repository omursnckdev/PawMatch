import Foundation

/// Public URLs for the legally-required documents. These must be live and
/// reachable **without an account** (§13). Replace with the real hosted URLs
/// before submission; they're referenced from the paywall, onboarding, and
/// Settings.
enum LegalLinks {
    static let termsOfService = URL(string: "https://pawmatch.app/terms")!
    static let privacyPolicy = URL(string: "https://pawmatch.app/privacy")!
    static let communityGuidelines = URL(string: "https://pawmatch.app/community-guidelines")!
    static let manageSubscription = URL(string: "itms-apps://apps.apple.com/account/subscriptions")!
}
