import CoreLocation
import FirebaseFirestore
@testable import PawMatch

final class MockAuthService: AuthServicing {
    var currentUserId: String?
    var signUpResult: Result<AuthResult, Error> = .failure(AuthServiceError.notSignedIn)
    var signInResult: Result<AuthResult, Error> = .failure(AuthServiceError.notSignedIn)
    var signInWithAppleResult: Result<AuthResult, Error> = .failure(AuthServiceError.notSignedIn)
    var signOutError: Error?
    private var continuation: AsyncStream<String?>.Continuation?

    func authStateStream() -> AsyncStream<String?> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(self.currentUserId)
        }
    }

    func emitAuthState(_ uid: String?) {
        currentUserId = uid
        continuation?.yield(uid)
    }

    func signUp(email: String, password: String) async throws -> AuthResult {
        try signUpResult.get()
    }

    func signIn(email: String, password: String) async throws -> AuthResult {
        try signInResult.get()
    }

    func signInWithApple(idTokenString: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthResult {
        try signInWithAppleResult.get()
    }

    func signOut() throws {
        if let signOutError {
            throw signOutError
        }
        emitAuthState(nil)
    }
}

final class MockUserService: UserServicing {
    var storedUsers: [String: AppUser] = [:]
    private(set) var createUserIfNeededCallCount = 0
    private(set) var confirmAgeCallCount = 0

    func fetchUser(uid: String) async throws -> AppUser? {
        storedUsers[uid]
    }

    func createUserIfNeeded(uid: String, displayName: String, email: String?, authProvider: AppUser.AuthProvider) async throws {
        createUserIfNeededCallCount += 1
        guard storedUsers[uid] == nil else { return }
        storedUsers[uid] = AppUser(
            id: uid,
            displayName: displayName,
            email: email,
            authProvider: authProvider,
            isPremium: false,
            billingIssue: false,
            dailySwipeCount: 0,
            lastSwipeResetDate: Timestamp(date: Date()),
            fcmToken: nil,
            blockedUserIds: [],
            isAgeConfirmed: false,
            createdAt: Timestamp(date: Date())
        )
    }

    func confirmAge(uid: String) async throws {
        confirmAgeCallCount += 1
        storedUsers[uid]?.isAgeConfirmed = true
    }
}

final class MockAnalyticsService: AnalyticsServicing {
    private(set) var loggedEventNames: [String] = []

    func log(_ event: AnalyticsEvent) {
        loggedEventNames.append(event.name)
    }
}

final class MockAppleSignInCoordinator: AppleSignInCoordinating {
    var result: Result<AppleSignInPayload, Error> = .failure(AppleSignInError.userCancelled)

    func signIn() async throws -> AppleSignInPayload {
        try result.get()
    }
}

final class MockPetService: PetServicing {
    var pets: [Pet] = []
    var fetchError: Error?
    var writeError: Error?
    private(set) var createdPets: [Pet] = []
    private(set) var updatedPets: [Pet] = []
    private(set) var deletedPetIds: [String] = []

    func newPetId() -> String { "pet-new" }

    func fetchPets(ownerId: String) async throws -> [Pet] {
        if let fetchError { throw fetchError }
        return pets.filter { $0.ownerId == ownerId }
    }

    func createPet(_ pet: Pet) async throws {
        if let writeError { throw writeError }
        createdPets.append(pet)
        pets.append(pet)
    }

    func updatePet(_ pet: Pet) async throws {
        if let writeError { throw writeError }
        updatedPets.append(pet)
    }

    func deletePet(petId: String) async throws {
        if let writeError { throw writeError }
        deletedPetIds.append(petId)
        pets.removeAll { $0.id == petId }
    }
}

final class MockStorageService: StorageServicing {
    private(set) var uploadCount = 0
    private(set) var deletedURLs: [String] = []

    func uploadPetPhoto(ownerId: String, petId: String, jpegData: Data) async throws -> String {
        uploadCount += 1
        return "https://example.com/\(petId)/\(uploadCount).jpg"
    }

    func deletePetPhoto(downloadURL: String) async throws {
        deletedURLs.append(downloadURL)
    }
}

final class MockLocationService: LocationServicing {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var requestedStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var locationResult: Result<CLLocationCoordinate2D, Error> = .success(
        CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0)
    )

    func requestWhenInUseAuthorization() async -> CLAuthorizationStatus {
        requestedStatus
    }

    func requestLocation() async throws -> CLLocationCoordinate2D {
        try locationResult.get()
    }
}

final class MockGeohashService: GeohashServicing {
    var stubbedGeohash = "test-geohash"

    func geohash(latitude: Double, longitude: Double) -> String {
        stubbedGeohash
    }
}

enum TestFixtures {
    static func pet(
        id: String = "pet-1",
        ownerId: String = "owner-1",
        name: String = "Rex"
    ) -> Pet {
        Pet(
            id: id,
            ownerId: ownerId,
            name: name,
            species: .dog,
            breed: "Corgi",
            age: 3,
            sex: .male,
            purposes: [.playdate],
            bio: "Good boy",
            photoUrls: ["https://example.com/existing.jpg"],
            latitude: 41.0,
            longitude: 29.0,
            geohash: "old-geohash",
            boostedUntil: nil,
            createdAt: Timestamp(date: Date(timeIntervalSince1970: 1_000))
        )
    }
}
