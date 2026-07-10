import FirebaseAnalytics

/// Thin wrapper around Firebase Analytics so call sites don't depend on the SDK
/// directly and event names are defined in one place (see §10.9).
enum AnalyticsEvent {
    case signUpCompleted(method: String)
    case petProfileCreated
    case swipePerformed(direction: String)
    case matchCreated
    case messageSent
    case paywallViewed(source: String)
    case paywallPurchaseCompleted(productId: String)
    case paywallDismissed

    var name: String {
        switch self {
        case .signUpCompleted: return "sign_up_completed"
        case .petProfileCreated: return "pet_profile_created"
        case .swipePerformed: return "swipe_performed"
        case .matchCreated: return "match_created"
        case .messageSent: return "message_sent"
        case .paywallViewed: return "paywall_viewed"
        case .paywallPurchaseCompleted: return "paywall_purchase_completed"
        case .paywallDismissed: return "paywall_dismissed"
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .signUpCompleted(let method): return ["method": method]
        case .swipePerformed(let direction): return ["direction": direction]
        case .paywallViewed(let source): return ["source": source]
        case .paywallPurchaseCompleted(let productId): return ["product_id": productId]
        case .petProfileCreated, .matchCreated, .messageSent, .paywallDismissed: return nil
        }
    }
}

protocol AnalyticsServicing {
    func log(_ event: AnalyticsEvent)
}

final class AnalyticsService: AnalyticsServicing {
    static let shared = AnalyticsService()

    func log(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters)
    }
}
