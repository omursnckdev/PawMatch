import FirebaseFirestore
import Foundation

final class SwipeService: SwipeServicing {
    static let shared = SwipeService()

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private var swipesCollection: CollectionReference {
        db.collection("swipes")
    }

    func recordSwipe(_ swipe: Swipe) async throws {
        _ = try swipesCollection.addDocument(from: swipe)
    }

    func fetchSwipedTargetPetIds(swiperUserId: String) async throws -> Set<String> {
        let snapshot = try await swipesCollection
            .whereField("swiperUserId", isEqualTo: swiperUserId)
            .getDocuments()
        let ids = snapshot.documents.compactMap { $0.data()["targetPetId"] as? String }
        return Set(ids)
    }

    func fetchIncomingSuperlikerPetIds(targetOwnerId: String, targetPetId: String) async throws -> Set<String> {
        // Query is constrained to `targetOwnerId == uid` so it satisfies the
        // swipes read rule (a bare `targetPetId ==` query would be rejected as
        // unauthorized). `targetPetId` + `direction` are filtered client-side,
        // avoiding an extra composite index.
        let snapshot = try await swipesCollection
            .whereField("targetOwnerId", isEqualTo: targetOwnerId)
            .getDocuments()
        let ids = snapshot.documents.compactMap { document -> String? in
            let data = document.data()
            guard data["targetPetId"] as? String == targetPetId,
                  data["direction"] as? String == Swipe.Direction.superlike.rawValue else { return nil }
            return data["swiperPetId"] as? String
        }
        return Set(ids)
    }

    func fetchIncomingLikerPetIds(targetOwnerId: String) async throws -> [String] {
        let snapshot = try await swipesCollection
            .whereField("targetOwnerId", isEqualTo: targetOwnerId)
            .whereField("direction", in: [Swipe.Direction.like.rawValue, Swipe.Direction.superlike.rawValue])
            .order(by: "timestamp", descending: true)
            .limit(to: 100)
            .getDocuments()
        // De-duplicate while preserving most-recent-first order.
        var seen = Set<String>()
        var ordered: [String] = []
        for document in snapshot.documents {
            guard let petId = document.data()["swiperPetId"] as? String, !seen.contains(petId) else { continue }
            seen.insert(petId)
            ordered.append(petId)
        }
        return ordered
    }
}
