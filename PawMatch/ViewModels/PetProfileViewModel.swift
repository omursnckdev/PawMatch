import CoreLocation
import FirebaseFirestore
import UIKit

/// Drives both creating a new pet and editing an existing one. Holds the draft
/// state across the multi-step setup flow, then on `save()` compresses + uploads
/// any newly-picked photos, resolves the pet's location + geohash, and writes the
/// `pets/{petId}` document.
@MainActor
final class PetProfileViewModel: ObservableObject {
    // Draft fields
    @Published var name = ""
    @Published var species: Pet.Species = .dog
    @Published var breed = ""
    @Published var ageText = ""
    @Published var sex: Pet.Sex = .male
    @Published var bio = ""
    @Published var purposes: Set<Pet.Purpose> = [.playdate]

    /// Photos newly picked in this session (not yet uploaded).
    @Published var newImages: [UIImage] = []
    /// Already-uploaded photo URLs retained from an edited pet.
    @Published private(set) var existingPhotoUrls: [String] = []

    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var isRequestingLocation = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let editingPetId: String?
    private let existingCreatedAt: Timestamp?
    private let existingBoostedUntil: Timestamp?

    private let petService: PetServicing
    private let storageService: StorageServicing
    private let locationService: LocationServicing
    private let geohashService: GeohashServicing
    private let analytics: AnalyticsServicing
    private let currentUserId: () -> String?

    init(
        editing pet: Pet? = nil,
        petService: PetServicing = PetService.shared,
        storageService: StorageServicing = StorageService.shared,
        locationService: LocationServicing = LocationService.shared,
        geohashService: GeohashServicing = GeohashService.shared,
        analytics: AnalyticsServicing = AnalyticsService.shared,
        currentUserId: @escaping () -> String? = { AuthService.shared.currentUserId }
    ) {
        self.petService = petService
        self.storageService = storageService
        self.locationService = locationService
        self.geohashService = geohashService
        self.analytics = analytics
        self.currentUserId = currentUserId

        if let pet {
            editingPetId = pet.id
            existingCreatedAt = pet.createdAt
            existingBoostedUntil = pet.boostedUntil
            name = pet.name
            species = pet.species
            breed = pet.breed
            ageText = String(pet.age)
            sex = pet.sex
            bio = pet.bio
            purposes = Set(pet.purposes)
            existingPhotoUrls = pet.photoUrls
            coordinate = CLLocationCoordinate2D(latitude: pet.latitude, longitude: pet.longitude)
        } else {
            editingPetId = nil
            existingCreatedAt = nil
            existingBoostedUntil = nil
        }
    }

    var isEditing: Bool { editingPetId != nil }

    var totalPhotoCount: Int { existingPhotoUrls.count + newImages.count }

    private var parsedAge: Int? {
        guard let age = Int(ageText.trimmingCharacters(in: .whitespaces)), age > 0, age < 100 else {
            return nil
        }
        return age
    }

    // MARK: - Per-step validation

    var isBasicsValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !breed.trimmingCharacters(in: .whitespaces).isEmpty
            && parsedAge != nil
    }

    var isPhotosValid: Bool { totalPhotoCount > 0 }
    var isPurposeValid: Bool { !purposes.isEmpty }
    var isLocationValid: Bool { coordinate != nil }

    var canSave: Bool {
        isBasicsValid && isPhotosValid && isPurposeValid && isLocationValid && !isSaving
    }

    // MARK: - Actions

    func togglePurpose(_ purpose: Pet.Purpose) {
        if purposes.contains(purpose) {
            // Keep at least one selected.
            if purposes.count > 1 { purposes.remove(purpose) }
        } else {
            purposes.insert(purpose)
        }
    }

    func addImages(_ images: [UIImage]) {
        newImages.append(contentsOf: images)
    }

    func removeNewImage(at index: Int) {
        guard newImages.indices.contains(index) else { return }
        newImages.remove(at: index)
    }

    func removeExistingPhoto(_ url: String) {
        existingPhotoUrls.removeAll { $0 == url }
    }

    func requestLocation() async {
        isRequestingLocation = true
        errorMessage = nil
        defer { isRequestingLocation = false }
        do {
            coordinate = try await locationService.requestLocation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Saves the pet. Returns the saved pet id on success, or nil on failure
    /// (with `errorMessage` populated).
    @discardableResult
    func save() async -> String? {
        guard let ownerId = currentUserId() else {
            errorMessage = AuthServiceError.notSignedIn.errorDescription
            return nil
        }
        guard let age = parsedAge, let coordinate else {
            errorMessage = String(localized: "error.generic")
            return nil
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let petId = editingPetId ?? petService.newPetId()

        do {
            let uploadedUrls = try await uploadNewImages(ownerId: ownerId, petId: petId)
            let photoUrls = existingPhotoUrls + uploadedUrls

            let pet = Pet(
                id: petId,
                ownerId: ownerId,
                name: name.trimmingCharacters(in: .whitespaces),
                species: species,
                breed: breed.trimmingCharacters(in: .whitespaces),
                age: age,
                sex: sex,
                purposes: Array(purposes),
                bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
                photoUrls: photoUrls,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                geohash: geohashService.geohash(latitude: coordinate.latitude, longitude: coordinate.longitude),
                boostedUntil: existingBoostedUntil,
                createdAt: existingCreatedAt ?? Timestamp(date: Date())
            )

            if isEditing {
                try await petService.updatePet(pet)
            } else {
                try await petService.createPet(pet)
                analytics.log(.petProfileCreated)
            }
            return petId
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func uploadNewImages(ownerId: String, petId: String) async throws -> [String] {
        var urls: [String] = []
        for image in newImages {
            guard let data = ImageProcessor.compressedJPEG(from: image) else { continue }
            let url = try await storageService.uploadPetPhoto(ownerId: ownerId, petId: petId, jpegData: data)
            urls.append(url)
        }
        return urls
    }
}
