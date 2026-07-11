import FirebaseFirestore

/// Mirrors a document at `reports/{reportId}`. Create-only from the client; the
/// report reason is a fixed set so reports are easy to triage (§10.8).
struct Report: Codable {
    @DocumentID var id: String?
    var reporterUserId: String
    var reportedUserId: String
    var reportedPetId: String?
    var reason: Reason
    var details: String?
    var createdAt: Timestamp

    enum Reason: String, Codable, CaseIterable, Identifiable {
        case spam
        case inappropriatePhoto
        case harassment
        case animalWelfare
        case other

        var id: String { rawValue }
    }
}
