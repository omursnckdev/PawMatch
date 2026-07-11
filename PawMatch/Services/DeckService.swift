import CoreLocation
import FirebaseFirestore
import GeoFireUtils

/// Runs the proximity deck query. Firestore can't do radius queries directly, so
/// we ask `GFUtils` for the set of geohash ranges ("bounds") that cover the
/// circle, fire one range query per bound in parallel, then filter the merged
/// results down to the true radius (§6.1, §10.3).
final class DeckService: DeckServicing {
    static let shared = DeckService()

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func fetchCandidates(
        center: CLLocationCoordinate2D,
        radiusMeters: Double,
        species: Pet.Species,
        purpose: Pet.Purpose?,
        limitPerBound: Int
    ) async throws -> [Pet] {
        let bounds = GFUtils.queryBounds(forLocation: center, withRadius: radiusMeters)

        let merged = try await withThrowingTaskGroup(of: [Pet].self) { group -> [String: Pet] in
            for bound in bounds {
                group.addTask {
                    try await self.fetchBound(
                        bound,
                        species: species,
                        purpose: purpose,
                        limit: limitPerBound
                    )
                }
            }

            var byId: [String: Pet] = [:]
            for try await pets in group {
                for pet in pets where pet.id != nil {
                    byId[pet.id!] = pet
                }
            }
            return byId
        }

        // Geohash bounds over-select at the edges; drop anything outside the
        // real radius using true great-circle distance.
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return merged.values.filter { pet in
            let petLocation = CLLocation(latitude: pet.latitude, longitude: pet.longitude)
            return centerLocation.distance(from: petLocation) <= radiusMeters
        }
    }

    private func fetchBound(
        _ bound: GFGeoQueryBound,
        species: Pet.Species,
        purpose: Pet.Purpose?,
        limit: Int
    ) async throws -> [Pet] {
        var query: Query = db.collection("pets")
            .whereField("species", isEqualTo: species.rawValue)

        if let purpose {
            query = query.whereField("purposes", arrayContains: purpose.rawValue)
        }

        query = query
            .order(by: "geohash")
            .start(at: [bound.startValue])
            .end(at: [bound.endValue])
            .limit(to: limit)

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Pet.self) }
    }
}
