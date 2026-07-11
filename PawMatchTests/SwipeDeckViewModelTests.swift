import FirebaseFirestore
import XCTest
@testable import PawMatch

@MainActor
final class SwipeDeckViewModelTests: XCTestCase {
    private var deckService: MockDeckService!
    private var swipeService: MockSwipeService!
    private var userService: MockUserService!
    private var analytics: MockAnalyticsService!

    private let activePet = TestFixtures.pet(id: "my-pet", ownerId: "owner-1", name: "Mine")

    override func setUp() {
        deckService = MockDeckService()
        swipeService = MockSwipeService()
        userService = MockUserService()
        analytics = MockAnalyticsService()
    }

    private func makeViewModel(now: Date = Date()) -> SwipeDeckViewModel {
        SwipeDeckViewModel(
            activePet: activePet,
            deckService: deckService,
            swipeService: swipeService,
            userService: userService,
            analytics: analytics,
            currentUserId: { "owner-1" },
            now: { now }
        )
    }

    func testLoadExcludesOwnSwipedAndBlockedPets() async {
        userService.storedUsers["owner-1"] = TestFixtures.user(blockedUserIds: ["blocker-owner"])
        deckService.candidates = [
            TestFixtures.pet(id: "my-pet", ownerId: "owner-1", name: "Mine"),      // own pet
            TestFixtures.pet(id: "swiped", ownerId: "owner-2", name: "Swiped"),    // already swiped
            TestFixtures.pet(id: "blocked", ownerId: "blocker-owner", name: "Blk"),// blocked owner
            TestFixtures.pet(id: "good", ownerId: "owner-3", name: "Good")         // keep
        ]
        swipeService.swipedTargetPetIds = ["swiped"]

        let vm = makeViewModel()
        await vm.load()

        XCTAssertEqual(vm.deck.map(\.pet.id), ["good"])
    }

    func testSuperlikedCandidatesSortToTop() async {
        userService.storedUsers["owner-1"] = TestFixtures.user()
        deckService.candidates = [
            TestFixtures.pet(id: "near", ownerId: "owner-2", name: "Near"),
            TestFixtures.pet(id: "superliker", ownerId: "owner-3", name: "Star")
        ]
        swipeService.incomingSuperlikerPetIds = ["superliker"]

        let vm = makeViewModel()
        await vm.load()

        XCTAssertEqual(vm.deck.first?.pet.id, "superliker")
        XCTAssertTrue(vm.deck.first?.isSuperlikedByTarget ?? false)
    }

    func testSwipeRecordsAndIncrementsCounter() async {
        userService.storedUsers["owner-1"] = TestFixtures.user(dailySwipeCount: 4)
        deckService.candidates = [TestFixtures.pet(id: "good", ownerId: "owner-3", name: "Good")]

        let vm = makeViewModel()
        await vm.load()
        let recorded = await vm.swipe(.like)

        XCTAssertTrue(recorded)
        XCTAssertEqual(swipeService.recordedSwipes.count, 1)
        XCTAssertEqual(swipeService.recordedSwipes.first?.direction, .like)
        XCTAssertEqual(userService.storedUsers["owner-1"]?.dailySwipeCount, 5)
        XCTAssertEqual(analytics.loggedEventNames, ["swipe_performed"])
        XCTAssertNil(vm.paywallSource)
    }

    func testFreeUserAtLimitShowsPaywallAndDoesNotRecord() async {
        userService.storedUsers["owner-1"] = TestFixtures.user(dailySwipeCount: 15)
        deckService.candidates = [TestFixtures.pet(id: "good", ownerId: "owner-3", name: "Good")]

        let vm = makeViewModel()
        await vm.load()
        let recorded = await vm.swipe(.like)

        XCTAssertFalse(recorded)
        XCTAssertTrue(swipeService.recordedSwipes.isEmpty)
        XCTAssertEqual(vm.paywallSource, .swipeLimit)
        // paywall_viewed is logged by PaywallViewModel when the sheet appears,
        // not here — so no swipe was recorded and no swipe event fired.
        XCTAssertFalse(analytics.loggedEventNames.contains("swipe_performed"))
    }

    func testNewDayResetsLimitAndAllowsSwipe() async {
        let yesterday = Date(timeIntervalSince1970: 1_000_000)
        let today = Date(timeIntervalSince1970: 1_000_000 + 86_400 * 3)
        userService.storedUsers["owner-1"] = TestFixtures.user(dailySwipeCount: 15, lastResetDate: yesterday)
        deckService.candidates = [TestFixtures.pet(id: "good", ownerId: "owner-3", name: "Good")]

        let vm = makeViewModel(now: today)
        await vm.load()
        let recorded = await vm.swipe(.like)

        XCTAssertTrue(recorded)
        // Reset to 0 for the new day, then +1 for this swipe.
        XCTAssertEqual(userService.storedUsers["owner-1"]?.dailySwipeCount, 1)
        XCTAssertNil(vm.paywallSource)
    }

    func testSuperlikeLimitShowsPaywall() async {
        userService.storedUsers["owner-1"] = TestFixtures.user(dailySwipeCount: 0, dailySuperlikeCount: 1)
        deckService.candidates = [TestFixtures.pet(id: "good", ownerId: "owner-3", name: "Good")]

        let vm = makeViewModel()
        await vm.load()
        let recorded = await vm.swipe(.superlike)

        XCTAssertFalse(recorded)
        XCTAssertEqual(vm.paywallSource, .superlikeLimit)
    }

    func testPremiumUserBypassesLimit() async {
        userService.storedUsers["owner-1"] = TestFixtures.user(isPremium: true, dailySwipeCount: 999)
        deckService.candidates = [TestFixtures.pet(id: "good", ownerId: "owner-3", name: "Good")]

        let vm = makeViewModel()
        await vm.load()
        let recorded = await vm.swipe(.like)

        XCTAssertTrue(recorded)
        XCTAssertNil(vm.paywallSource)
        XCTAssertNil(vm.remainingSwipes)
    }

    func testAdShownAfterTenSwipesForFreeUser() async {
        userService.storedUsers["owner-1"] = TestFixtures.user(isPremium: false)
        deckService.candidates = (0..<20).map { TestFixtures.pet(id: "p\($0)", ownerId: "owner-\($0 + 2)", name: "P\($0)") }

        let vm = makeViewModel()
        await vm.load()

        for _ in 0..<9 {
            _ = await vm.swipe(.pass)
            XCTAssertFalse(vm.showAd)
        }
        _ = await vm.swipe(.pass) // 10th swipe
        XCTAssertTrue(vm.showAd)

        vm.dismissAd()
        XCTAssertFalse(vm.showAd)
    }

    func testAdNeverShownForPremiumUser() async {
        userService.storedUsers["owner-1"] = TestFixtures.user(isPremium: true)
        deckService.candidates = (0..<20).map { TestFixtures.pet(id: "p\($0)", ownerId: "owner-\($0 + 2)", name: "P\($0)") }

        let vm = makeViewModel()
        await vm.load()

        for _ in 0..<15 {
            _ = await vm.swipe(.pass)
            XCTAssertFalse(vm.showAd)
        }
    }

    func testDeckExhaustionAfterSwipingAll() async {
        userService.storedUsers["owner-1"] = TestFixtures.user()
        deckService.candidates = [TestFixtures.pet(id: "only", ownerId: "owner-3", name: "Only")]

        let vm = makeViewModel()
        await vm.load()
        XCTAssertFalse(vm.isDeckExhausted)

        _ = await vm.swipe(.pass)
        XCTAssertTrue(vm.isDeckExhausted)
    }
}
