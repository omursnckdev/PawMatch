import CoreLocation

protocol DeckServicing {
    /// Returns candidate pets of the given species within `radiusMeters` of
    /// `center`, using geohash range bucketing (§6.1). Optionally constrained to
    /// a match purpose (a PawMatch Plus advanced filter). Results are already
    /// distance-filtered to the true radius; the caller is responsible for
    /// excluding own/blocked/already-swiped pets.
    func fetchCandidates(
        center: CLLocationCoordinate2D,
        radiusMeters: Double,
        species: Pet.Species,
        purpose: Pet.Purpose?,
        limitPerBound: Int
    ) async throws -> [Pet]
}
