import FirebaseFirestore

/// Mirrors a document at `swipes/{swipeId}`. Created by the client, never updated;
/// reciprocity is checked server-side by the `onSwipeCreated` Cloud Function.
struct Swipe: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var swiperUserId: String
    var swiperPetId: String
    var targetPetId: String
    var targetOwnerId: String
    var direction: Direction
    var timestamp: Timestamp

    enum Direction: String, Codable {
        case like
        case pass
        case superlike
    }
}
