import Foundation

@MainActor
final class LikesViewModel: ObservableObject {
    @Published private(set) var pets: [Pet] = []
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    private let swipeService: SwipeServicing
    private let petService: PetServicing
    private let userService: UserServicing
    private let currentUserId: () -> String?

    init(
        swipeService: SwipeServicing = SwipeService.shared,
        petService: PetServicing = PetService.shared,
        userService: UserServicing = UserService.shared,
        currentUserId: @escaping () -> String? = { AuthService.shared.currentUserId }
    ) {
        self.swipeService = swipeService
        self.petService = petService
        self.userService = userService
        self.currentUserId = currentUserId
    }

    func load() async {
        guard let uid = currentUserId() else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let blocked = Set((try? await userService.fetchUser(uid: uid))?.blockedUserIds ?? [])
            let petIds = try await swipeService.fetchIncomingLikerPetIds(targetOwnerId: uid)
            var resolved: [Pet] = []
            for petId in petIds {
                if let pet = try await petService.fetchPet(petId: petId), !blocked.contains(pet.ownerId) {
                    resolved.append(pet)
                }
            }
            pets = resolved
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
