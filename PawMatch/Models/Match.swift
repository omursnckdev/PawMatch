import FirebaseFirestore

/// Mirrors a document at `matches/{matchId}`. Written only by Cloud Functions;
/// client-side writes must be rejected in security rules.
struct Match: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var petIds: [String]
    var userIds: [String]
    var purpose: Pet.Purpose
    var matchedAt: Timestamp
    var lastMessage: String?
    var lastMessageAt: Timestamp?
}
