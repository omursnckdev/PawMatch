import CoreLocation
import GeoFireUtils

/// Wraps `GFUtils` so call sites don't depend on GeoFireUtils directly and the
/// geohash implementation can be swapped without touching ViewModels (§6.1).
protocol GeohashServicing {
    func geohash(latitude: Double, longitude: Double) -> String
}

final class GeohashService: GeohashServicing {
    static let shared = GeohashService()

    func geohash(latitude: Double, longitude: Double) -> String {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        return GFUtils.geoHash(forLocation: coordinate)
    }
}
