import FirebaseStorage
import Foundation

final class StorageService: StorageServicing {
    static let shared = StorageService()

    private let storage: Storage

    init(storage: Storage = Storage.storage()) {
        self.storage = storage
    }

    func uploadPetPhoto(ownerId: String, petId: String, jpegData: Data) async throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let ref = storage.reference().child("petPhotos/\(ownerId)/\(petId)/\(fileName)")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        _ = try await ref.putDataAsync(jpegData, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func deletePetPhoto(downloadURL: String) async throws {
        // storage.reference(forURL:) throws if the URL isn't a gs://... or a
        // recognized download URL for this bucket; callers treat any failure as
        // non-fatal so a stale/foreign URL doesn't block the rest of a save.
        let ref = storage.reference(forURL: downloadURL)
        try await ref.delete()
    }
}
