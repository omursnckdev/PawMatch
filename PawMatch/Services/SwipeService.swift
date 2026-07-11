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

    func fetchIncomingSuperlikerPetIds(targetPetId: String) async throws -> Set<String> {
        // Filter `direction` client-side so this needs only the single-field
        // auto-index on `targetPetId` rather than a dedicated composite index.
        let snapshot = try await swipesCollection
            .whereField("targetPetId", isEqualTo: targetPetId)
            .getDocuments()
        let ids = snapshot.documents.compactMap { document -> String? in
            let data = document.data()
            guard data["direction"] as? String == Swipe.Direction.superlike.rawValue else { return nil }
            return data["swiperPetId"] as? String
        }
        return Set(ids)
    }
}
