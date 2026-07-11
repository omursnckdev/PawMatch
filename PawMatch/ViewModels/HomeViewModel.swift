import Foundation

/// Loads the signed-in user's pets and decides whether to route into first-run
/// profile setup (0 pets) or the main experience (≥1 pet). Also backs the
/// "Manage Pets" screen's add/edit/delete actions so both stay in sync.
@MainActor
final class HomeViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case needsFirstPet
        case ready([Pet])
        case error(String)
    }

    @Published private(set) var state: State = .loading

    private let petService: PetServicing
    private let storageService: StorageServicing
    private let currentUserId: () -> String?

    init(
        petService: PetServicing = PetService.shared,
        storageService: StorageServicing = StorageService.shared,
        currentUserId: @escaping () -> String? = { AuthService.shared.currentUserId }
    ) {
        self.petService = petService
        self.storageService = storageService
        self.currentUserId = currentUserId
    }

    var pets: [Pet] {
        if case .ready(let pets) = state { return pets }
        return []
    }

    func load() async {
        guard let uid = currentUserId() else {
            state = .error(AuthServiceError.notSignedIn.errorDescription ?? "")
            return
        }
        state = .loading
        do {
            let pets = try await petService.fetchPets(ownerId: uid)
            state = pets.isEmpty ? .needsFirstPet : .ready(pets.sorted { $0.createdAt.seconds < $1.createdAt.seconds })
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func deletePet(_ pet: Pet) async {
        guard let id = pet.id else { return }
        do {
            try await petService.deletePet(petId: id)
            // Best-effort cleanup of the pet's photos; failures are non-fatal.
            for url in pet.photoUrls {
                try? await storageService.deletePetPhoto(downloadURL: url)
            }
            await load()
        } catch {
            state = .error(error.localizedDescription)
        }
    }
}
