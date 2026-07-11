import Foundation

protocol PetServicing {
    /// A fresh, unused document id so photos can be uploaded to a stable
    /// `petPhotos/{ownerId}/{petId}/...` path before the pet document is written.
    func newPetId() -> String

    func fetchPets(ownerId: String) async throws -> [Pet]
    func fetchPet(petId: String) async throws -> Pet?
    func createPet(_ pet: Pet) async throws
    func updatePet(_ pet: Pet) async throws
    func deletePet(petId: String) async throws
}
