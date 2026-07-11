import XCTest
@testable import PawMatch

@MainActor
final class MatchesViewModelTests: XCTestCase {
    private var matchService: MockMatchService!
    private var petService: MockPetService!
    private var userService: MockUserService!

    override func setUp() {
        matchService = MockMatchService()
        petService = MockPetService()
        userService = MockUserService()
    }

    private func makeViewModel() -> MatchesViewModel {
        MatchesViewModel(
            matchService: matchService,
            petService: petService,
            userService: userService,
            currentUserId: { "owner-1" }
        )
    }

    /// Polls until `condition` holds or a timeout elapses, since `start()`
    /// resolves rows on a detached Task fed by an AsyncStream.
    private func waitUntil(_ condition: @escaping () -> Bool) async {
        for _ in 0..<50 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testResolvesOtherPetForMatch() async {
        petService.pets = [
            TestFixtures.pet(id: "petA", ownerId: "owner-1", name: "Mine"),
            TestFixtures.pet(id: "petB", ownerId: "owner-2", name: "Theirs")
        ]
        matchService.matchesToEmit = [TestFixtures.match()]

        let vm = makeViewModel()
        vm.start()
        await waitUntil { !vm.rows.isEmpty }

        XCTAssertEqual(vm.rows.count, 1)
        XCTAssertEqual(vm.rows.first?.otherPet.id, "petB")
        XCTAssertEqual(vm.rows.first?.otherUserId, "owner-2")
    }

    func testFiltersOutBlockedUsers() async {
        userService.storedUsers["owner-1"] = TestFixtures.user(id: "owner-1", blockedUserIds: ["owner-2"])
        petService.pets = [
            TestFixtures.pet(id: "petA", ownerId: "owner-1", name: "Mine"),
            TestFixtures.pet(id: "petB", ownerId: "owner-2", name: "Theirs")
        ]
        matchService.matchesToEmit = [TestFixtures.match()]

        let vm = makeViewModel()
        vm.start()
        await waitUntil { !vm.isLoading }

        XCTAssertTrue(vm.rows.isEmpty)
    }
}
