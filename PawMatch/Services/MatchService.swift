import FirebaseFirestore
import Foundation

final class MatchService: MatchServicing {
    static let shared = MatchService()

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func observeMatches(userId: String) -> AsyncStream<[Match]> {
        let query = db.collection("matches")
            .whereField("userIds", arrayContains: userId)
            .order(by: "matchedAt", descending: true)
        return FirestoreListener.stream(query, as: Match.self)
    }

    func fetchMatch(matchId: String) async throws -> Match? {
        let snapshot = try await db.collection("matches").document(matchId).getDocument()
        return try snapshot.data(as: Match.self)
    }
}
