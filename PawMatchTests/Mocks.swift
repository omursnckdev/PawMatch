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
            dailySuperlikeCount: 0,
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

    func updateSwipeCounters(uid: String, swipeCount: Int, superlikeCount: Int, lastResetDate: Date) async throws {
        storedUsers[uid]?.dailySwipeCount = swipeCount
        storedUsers[uid]?.dailySuperlikeCount = superlikeCount
        storedUsers[uid]?.lastSwipeResetDate = Timestamp(date: lastResetDate)
    }

    func setBlocked(uid: String, otherUserId: String, isBlocked: Bool) async throws {
        var blocked = Set(storedUsers[uid]?.blockedUserIds ?? [])
        if isBlocked { blocked.insert(otherUserId) } else { blocked.remove(otherUserId) }
        storedUsers[uid]?.blockedUserIds = Array(blocked)
    }

    func setActiveChat(uid: String, matchId: String?) async throws {}

    func updateFCMToken(uid: String, token: String) async throws {
        storedUsers[uid]?.fcmToken = token
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

    func fetchPet(petId: String) async throws -> Pet? {
        if let fetchError { throw fetchError }
        return pets.first { $0.id == petId }
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

final class MockDeckService: DeckServicing {
    var candidates: [Pet] = []
    var error: Error?
    private(set) var fetchCallCount = 0

    func fetchCandidates(
        center: CLLocationCoordinate2D,
        radiusMeters: Double,
        species: Pet.Species,
        purpose: Pet.Purpose?,
        limitPerBound: Int
    ) async throws -> [Pet] {
        fetchCallCount += 1
        if let error { throw error }
        return candidates
    }
}

final class MockSwipeService: SwipeServicing {
    var swipedTargetPetIds: Set<String> = []
    var incomingSuperlikerPetIds: Set<String> = []
    var recordError: Error?
    private(set) var recordedSwipes: [Swipe] = []

    func recordSwipe(_ swipe: Swipe) async throws {
        if let recordError { throw recordError }
        recordedSwipes.append(swipe)
    }

    func fetchSwipedTargetPetIds(swiperUserId: String) async throws -> Set<String> {
        swipedTargetPetIds
    }

    func fetchIncomingSuperlikerPetIds(targetOwnerId: String, targetPetId: String) async throws -> Set<String> {
        incomingSuperlikerPetIds
    }

    var incomingLikerPetIds: [String] = []
    func fetchIncomingLikerPetIds(targetOwnerId: String) async throws -> [String] {
        incomingLikerPetIds
    }
}

final class MockMatchService: MatchServicing {
    var matchesToEmit: [Match] = []

    func observeMatches(userId: String) -> AsyncStream<[Match]> {
        let matches = matchesToEmit
        return AsyncStream { continuation in
            continuation.yield(matches)
            continuation.finish()
        }
    }

    func fetchMatch(matchId: String) async throws -> Match? {
        matchesToEmit.first { $0.id == matchId }
    }
}

final class MockChatService: ChatServicing {
    var messagesToEmit: [ChatMessage] = []
    var sendError: Error?
    private(set) var sentMessages: [(matchId: String, senderId: String, text: String)] = []
    private(set) var markedReadIds: [String] = []

    func observeMessages(matchId: String) -> AsyncStream<[ChatMessage]> {
        let messages = messagesToEmit
        return AsyncStream { continuation in
            continuation.yield(messages)
            continuation.finish()
        }
    }

    func sendMessage(matchId: String, senderId: String, text: String) async throws {
        if let sendError { throw sendError }
        sentMessages.append((matchId, senderId, text))
    }

    func markMessagesRead(matchId: String, userId: String, messageIds: [String]) async throws {
        markedReadIds.append(contentsOf: messageIds)
    }
}

final class MockAccountService: AccountServicing {
    var error: Error?
    private(set) var deleteCallCount = 0

    func deleteAccount() async throws {
        deleteCallCount += 1
        if let error { throw error }
    }
}

final class MockReportService: ReportServicing {
    private(set) var reports: [(reported: String, reason: Report.Reason)] = []

    func submitReport(
        reporterUserId: String,
        reportedUserId: String,
        reportedPetId: String?,
        reason: Report.Reason,
        details: String?
    ) async throws {
        reports.append((reportedUserId, reason))
    }
}

enum TestFixtures {
    static func user(
        id: String = "owner-1",
        isPremium: Bool = false,
        dailySwipeCount: Int = 0,
        dailySuperlikeCount: Int = 0,
        lastResetDate: Date = Date(),
        blockedUserIds: [String] = []
    ) -> AppUser {
        AppUser(
            id: id,
            displayName: "Owner",
            email: "owner@example.com",
            authProvider: .email,
            isPremium: isPremium,
            billingIssue: false,
            dailySwipeCount: dailySwipeCount,
            dailySuperlikeCount: dailySuperlikeCount,
            lastSwipeResetDate: Timestamp(date: lastResetDate),
            fcmToken: nil,
            blockedUserIds: blockedUserIds,
            isAgeConfirmed: true,
            createdAt: Timestamp(date: Date(timeIntervalSince1970: 0))
        )
    }

    static func match(
        id: String = "petA_petB",
        petIds: [String] = ["petA", "petB"],
        userIds: [String] = ["owner-1", "owner-2"]
    ) -> Match {
        Match(
            id: id,
            petIds: petIds,
            userIds: userIds,
            purpose: .playdate,
            matchedAt: Timestamp(date: Date()),
            lastMessage: nil,
            lastMessageAt: nil
        )
    }

    static func message(
        id: String = "m1",
        senderId: String = "owner-2",
        text: String = "Hi",
        readBy: [String] = ["owner-2"]
    ) -> ChatMessage {
        ChatMessage(id: id, senderId: senderId, text: text, timestamp: Timestamp(date: Date()), readBy: readBy)
    }

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
