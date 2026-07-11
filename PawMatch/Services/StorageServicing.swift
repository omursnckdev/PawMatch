import Foundation

protocol StorageServicing {
    /// Uploads already-compressed JPEG data and returns the public download URL string.
    func uploadPetPhoto(ownerId: String, petId: String, jpegData: Data) async throws -> String

    /// Best-effort delete of a previously uploaded photo by its download URL.
    /// Failures are non-fatal (the URL may already be gone) and are ignored by callers.
    func deletePetPhoto(downloadURL: String) async throws
}
