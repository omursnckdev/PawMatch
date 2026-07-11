import XCTest
@testable import PawMatch

@MainActor
final class HomeViewModelTests: XCTestCase {
    private var petService: MockPetService!
    private var storageService: MockStorageService!

    override func setUp() {
        petService = MockPetService()
        storageService = MockStorageService()
    }

    private func makeViewModel(uid: String? = "owner-1") -> HomeViewModel {
        HomeViewModel(
            petService: petService,
            storageService: storageService,
            currentUserId: { uid }
        )
    }

    func testLoadRoutesToFirstPetWhenNoPets() async {
        let vm = makeViewModel()
        await vm.load()
        XCTAssertEqual(vm.state, .needsFirstPet)
    }

    func testLoadRoutesToReadyWhenPetsExist() async {
        petService.pets = [TestFixtures.pet(id: "pet-1")]
        let vm = makeViewModel()
        await vm.load()

        guard case .ready(let pets) = vm.state else {
            return XCTFail("Expected ready state, got \(vm.state)")
        }
        XCTAssertEqual(pets.count, 1)
    }

    func testLoadSurfacesErrorState() async {
        petService.fetchError = PetServiceError.missingId
        let vm = makeViewModel()
        await vm.load()

        guard case .error = vm.state else {
            return XCTFail("Expected error state, got \(vm.state)")
        }
    }

    func testDeletePetRemovesItAndCleansUpPhotos() async {
        let pet = TestFixtures.pet(id: "pet-1")
        petService.pets = [pet]
        let vm = makeViewModel()
        await vm.load()

        await vm.deletePet(pet)

        XCTAssertEqual(petService.deletedPetIds, ["pet-1"])
        XCTAssertEqual(storageService.deletedURLs, pet.photoUrls)
        XCTAssertEqual(vm.state, .needsFirstPet) // no pets left
    }
}
