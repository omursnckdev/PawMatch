import CoreLocation

protocol LocationServicing {
    var authorizationStatus: CLAuthorizationStatus { get }

    /// Presents the system "When In Use" prompt (if not already decided) and
    /// returns the resulting status.
    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus

    /// One-shot current location. Throws if permission is denied or the fix fails.
    func requestLocation() async throws -> CLLocationCoordinate2D
}

enum LocationServiceError: LocalizedError {
    case permissionDenied
    case unavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission is off. Enable it in Settings so we can show nearby pets."
        case .unavailable:
            return "We couldn't determine your location. Please try again."
        }
    }
}
