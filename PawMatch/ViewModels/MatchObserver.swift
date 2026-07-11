import Foundation

/// Watches the matches stream and surfaces *newly formed* matches (created after
/// this observer started) so the "It's a Match!" modal can be presented, without
/// re-firing for matches that already existed at launch.
@MainActor
final class MatchObserver: ObservableObject {
    @Published var newMatch: MatchRow?

    private let matchService: MatchServicing
    private let petService: PetServicing
    private let currentUserId: () -> String?

    private var observeTask: Task<Void, Never>?
    private var knownMatchIds: Set<String> = []
    private var hasBaseline = false

    init(
        matchService: MatchServicing = MatchService.shared,
        petService: PetServicing = PetService.shared,
        currentUserId: @escaping () -> String? = { AuthService.shared.currentUserId }
    ) {
        self.matchService = matchService
        self.petService = petService
        self.currentUserId = currentUserId
    }

    deinit { observeTask?.cancel() }

    func start() {
        guard observeTask == nil, let uid = currentUserId() else { return }
        observeTask = Task { [weak self] in
            guard let self else { return }
            for await matches in self.matchService.observeMatches(userId: uid) {
                await self.handle(matches, currentUserId: uid)
            }
        }
    }

    func dismiss() {
        newMatch = nil
    }

    private func handle(_ matches: [Match], currentUserId uid: String) async {
        let ids = Set(matches.compactMap { $0.id })

        // The first snapshot is the baseline of pre-existing matches — record it
        // and don't present a modal for any of them.
        guard hasBaseline else {
            knownMatchIds = ids
            hasBaseline = true
            return
        }

        let newIds = ids.subtracting(knownMatchIds)
        knownMatchIds = ids
        guard let newestNewId = newIds.first,
              let match = matches.first(where: { $0.id == newestNewId }),
              let otherUserId = match.userIds.first(where: { $0 != uid }) else {
            return
        }

        for petId in match.petIds {
            if let pet = try? await petService.fetchPet(petId: petId), pet.ownerId == otherUserId {
                newMatch = MatchRow(match: match, otherPet: pet, otherUserId: otherUserId)
                return
            }
        }
    }
}
