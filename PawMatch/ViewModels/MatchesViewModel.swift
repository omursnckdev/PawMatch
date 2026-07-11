import Foundation

/// A match paired with the other participant's pet, ready for display.
struct MatchRow: Identifiable, Equatable {
    let match: Match
    let otherPet: Pet
    let otherUserId: String
    var id: String { match.id ?? otherPet.id ?? UUID().uuidString }
}

@MainActor
final class MatchesViewModel: ObservableObject {
    @Published private(set) var rows: [MatchRow] = []
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    private let matchService: MatchServicing
    private let petService: PetServicing
    private let userService: UserServicing
    private let currentUserId: () -> String?

    private var observeTask: Task<Void, Never>?
    private var petCache: [String: Pet] = [:]
    private var blockedUserIds: Set<String> = []

    init(
        matchService: MatchServicing = MatchService.shared,
        petService: PetServicing = PetService.shared,
        userService: UserServicing = UserService.shared,
        currentUserId: @escaping () -> String? = { AuthService.shared.currentUserId }
    ) {
        self.matchService = matchService
        self.petService = petService
        self.userService = userService
        self.currentUserId = currentUserId
    }

    deinit { observeTask?.cancel() }

    func start() {
        guard observeTask == nil, let uid = currentUserId() else { return }
        observeTask = Task { [weak self] in
            guard let self else { return }
            if let user = try? await self.userService.fetchUser(uid: uid) {
                self.blockedUserIds = Set(user.blockedUserIds)
            }
            for await matches in self.matchService.observeMatches(userId: uid) {
                await self.resolve(matches, currentUserId: uid)
            }
        }
    }

    private func resolve(_ matches: [Match], currentUserId uid: String) async {
        var resolved: [MatchRow] = []
        for match in matches {
            guard let otherUserId = match.userIds.first(where: { $0 != uid }),
                  !blockedUserIds.contains(otherUserId) else {
                continue
            }
            // Pick the match's pet that belongs to the other user by resolving
            // each pet's ownerId, rather than assuming petIds/userIds order.
            var otherPet: Pet?
            for petId in match.petIds {
                if let pet = try? await pet(for: petId), pet.ownerId == otherUserId {
                    otherPet = pet
                    break
                }
            }
            if let otherPet {
                resolved.append(MatchRow(match: match, otherPet: otherPet, otherUserId: otherUserId))
            }
        }
        rows = resolved
        isLoading = false
    }

    private func pet(for petId: String) async throws -> Pet? {
        if let cached = petCache[petId] { return cached }
        let pet = try await petService.fetchPet(petId: petId)
        if let pet { petCache[petId] = pet }
        return pet
    }
}
