import CoreLocation
import UIKit
import XCTest
@testable import PawMatch

@MainActor
final class PetProfileViewModelTests: XCTestCase {
    private var petService: MockPetService!
    private var storageService: MockStorageService!
    private var locationService: MockLocationService!
    private var geohashService: MockGeohashService!
    private var analytics: MockAnalyticsService!

    override func setUp() {
        petService = MockPetService()
        storageService = MockStorageService()
        locationService = MockLocationService()
        geohashService = MockGeohashService()
        analytics = MockAnalyticsService()
    }

    private func makeViewModel(editing pet: Pet? = nil, uid: String? = "owner-1") -> PetProfileViewModel {
        PetProfileViewModel(
            editing: pet,
            petService: petService,
            storageService: storageService,
            locationService: locationService,
            geohashService: geohashService,
            analytics: analytics,
            currentUserId: { uid }
        )
    }

    private func solidImage() -> UIImage {
        let size = CGSize(width: 10, height: 10)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func testNewProfileIsInvalidUntilAllStepsSatisfied() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isBasicsValid)
        XCTAssertFalse(vm.isPhotosValid)
        XCTAssertTrue(vm.isPurposeValid) // defaults to [.playdate]
        XCTAssertFalse(vm.isLocationValid)
        XCTAssertFalse(vm.canSave)

        vm.name = "Rex"
        vm.breed = "Corgi"
        vm.ageText = "3"
        XCTAssertTrue(vm.isBasicsValid)
    }

    func testTogglePurposeAlwaysKeepsAtLeastOne() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.purposes, [.playdate])

        vm.togglePurpose(.playdate) // would empty the set — must be ignored
        XCTAssertEqual(vm.purposes, [.playdate])

        vm.togglePurpose(.breeding)
        XCTAssertEqual(vm.purposes, [.playdate, .breeding])

        vm.togglePurpose(.playdate)
        XCTAssertEqual(vm.purposes, [.breeding])
    }

    func testRequestLocationPopulatesCoordinate() async {
        let vm = makeViewModel()
        locationService.locationResult = .success(CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12))

        await vm.requestLocation()

        XCTAssertTrue(vm.isLocationValid)
        XCTAssertNil(vm.errorMessage)
    }

    func testRequestLocationFailureSurfacesError() async {
        let vm = makeViewModel()
        locationService.locationResult = .failure(LocationServiceError.permissionDenied)

        await vm.requestLocation()

        XCTAssertFalse(vm.isLocationValid)
        XCTAssertEqual(vm.errorMessage, LocationServiceError.permissionDenied.errorDescription)
    }

    func testSaveCreatesPetUploadsPhotosAndLogsAnalytics() async {
        let vm = makeViewModel()
        vm.name = "  Rex  "
        vm.breed = "Corgi"
        vm.ageText = "3"
        vm.togglePurpose(.breeding)
        vm.addImages([solidImage(), solidImage()])
        await vm.requestLocation()

        let savedId = await vm.save()

        XCTAssertEqual(savedId, "pet-new")
        XCTAssertEqual(storageService.uploadCount, 2)
        XCTAssertEqual(petService.createdPets.count, 1)

        let created = petService.createdPets[0]
        XCTAssertEqual(created.id, "pet-new")
        XCTAssertEqual(created.ownerId, "owner-1")
        XCTAssertEqual(created.name, "Rex") // trimmed
        XCTAssertEqual(created.photoUrls.count, 2)
        XCTAssertEqual(created.geohash, "test-geohash")
        XCTAssertEqual(Set(created.purposes), [.playdate, .breeding])
        XCTAssertEqual(analytics.loggedEventNames, ["pet_profile_created"])
    }

    func testSaveWhileEditingUpdatesInPlaceKeepingIdAndCreatedAt() async {
        let existing = TestFixtures.pet()
        let vm = makeViewModel(editing: existing)
        XCTAssertTrue(vm.isEditing)
        XCTAssertTrue(vm.isLocationValid) // seeded from existing pet
        XCTAssertTrue(vm.isPhotosValid)   // existing photo retained

        vm.name = "Rex II"

        let savedId = await vm.save()

        XCTAssertEqual(savedId, "pet-1")
        XCTAssertTrue(petService.createdPets.isEmpty)
        XCTAssertEqual(petService.updatedPets.count, 1)

        let updated = petService.updatedPets[0]
        XCTAssertEqual(updated.id, "pet-1")
        XCTAssertEqual(updated.name, "Rex II")
        XCTAssertEqual(updated.createdAt, existing.createdAt) // preserved
        XCTAssertEqual(updated.geohash, "test-geohash") // recomputed on save
        XCTAssertTrue(analytics.loggedEventNames.isEmpty) // edit is not a "created" event
    }

    func testSaveFailsWhenNotSignedIn() async {
        let vm = makeViewModel(uid: nil)
        vm.name = "Rex"
        vm.breed = "Corgi"
        vm.ageText = "3"
        vm.addImages([solidImage()])
        await vm.requestLocation()

        let savedId = await vm.save()

        XCTAssertNil(savedId)
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(petService.createdPets.isEmpty)
    }

    func testSaveSurfacesWriteError() async {
        petService.writeError = PetServiceError.missingId
        let vm = makeViewModel()
        vm.name = "Rex"
        vm.breed = "Corgi"
        vm.ageText = "3"
        vm.addImages([solidImage()])
        await vm.requestLocation()

        let savedId = await vm.save()

        XCTAssertNil(savedId)
        XCTAssertEqual(vm.errorMessage, PetServiceError.missingId.errorDescription)
    }
}
