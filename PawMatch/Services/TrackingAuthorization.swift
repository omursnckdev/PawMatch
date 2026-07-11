import AppTrackingTransparency
import AdSupport

/// Thin wrapper around App Tracking Transparency (§10.4). The OS prompt is
/// preceded by an in-app priming screen (§9) — this only fires the request and
/// exposes the current status for ad personalization decisions.
enum TrackingAuthorization {
    static var isAuthorized: Bool {
        ATTrackingManager.trackingAuthorizationStatus == .authorized
    }

    static var isDetermined: Bool {
        ATTrackingManager.trackingAuthorizationStatus != .notDetermined
    }

    @discardableResult
    static func requestIfNeeded() async -> ATTrackingManager.AuthorizationStatus {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            return ATTrackingManager.trackingAuthorizationStatus
        }
        return await ATTrackingManager.requestTrackingAuthorization()
    }
}
