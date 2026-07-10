import FirebaseFirestore

/// Mirrors a document at `pets/{petId}`.
struct Pet: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var ownerId: String
    var name: String
    var species: Species
    var breed: String
    var age: Int
    var sex: Sex
    var purposes: [Purpose]
    var bio: String
    var photoUrls: [String]
    var latitude: Double
    var longitude: Double
    var geohash: String
    var boostedUntil: Timestamp?
    var createdAt: Timestamp

    enum Species: String, Codable, CaseIterable {
        case dog
        case cat
        case other
    }

    enum Sex: String, Codable, CaseIterable {
        case male
        case female
    }

    enum Purpose: String, Codable, CaseIterable {
        case playdate
        case breeding
    }
}
