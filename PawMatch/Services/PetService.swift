import FirebaseFirestore
import Foundation

final class PetService: PetServicing {
    static let shared = PetService()

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private var petsCollection: CollectionReference {
        db.collection("pets")
    }

    func newPetId() -> String {
        petsCollection.document().documentID
    }

    func fetchPets(ownerId: String) async throws -> [Pet] {
        let snapshot = try await petsCollection
            .whereField("ownerId", isEqualTo: ownerId)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Pet.self) }
    }

    func createPet(_ pet: Pet) async throws {
        guard let id = pet.id else {
            throw PetServiceError.missingId
        }
        try petsCollection.document(id).setData(from: pet)
    }

    func updatePet(_ pet: Pet) async throws {
        guard let id = pet.id else {
            throw PetServiceError.missingId
        }
        try petsCollection.document(id).setData(from: pet, merge: true)
    }

    func deletePet(petId: String) async throws {
        try await petsCollection.document(petId).delete()
    }
}

enum PetServiceError: LocalizedError {
    case missingId

    var errorDescription: String? {
        switch self {
        case .missingId:
            return "This pet is missing an identifier and can't be saved."
        }
    }
}
