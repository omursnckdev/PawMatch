import CoreLocation
import FirebaseFirestore
import Foundation

/// A single swipeable card: the candidate pet plus derived display data.
struct DeckCard: Identifiable, Equatable {
    let pet: Pet
    let distanceKm: Double
    let isSuperlikedByTarget: Bool
    var id: String { pet.id ?? pet.name }
}

/// Reason the paywall was surfaced from the deck, used for the analytics
/// `paywall_viewed` source parameter.
enum PaywallSource: String, Identifiable {
    case swipeLimit = "swipe_limit"
    case superlikeLimit = "superlike_limit"
    case secondPet = "second_pet"
    case likesTab = "likes_tab"
    case rewind = "rewind"
    case boost = "boost"

    var id: String { rawValue }
}

@MainActor
final class SwipeDeckViewModel: ObservableObject {
    @Published private(set) var deck: [DeckCard] = []
    @Published private(set) var topIndex = 0
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var paywallSource: PaywallSource?

    /// True when an ad card should be shown before the next pet card — set every
    /// 10th swipe for free users only (§8). The view renders `NativeAdCardView`
    /// while this is true and calls `dismissAd()` to continue.
    @Published private(set) var showAd = false

    /// Insert an ad after every N swiped cards.
    static let adFrequency = 10
    private var swipesSinceAd = 0

    /// Search radius for the deck query. A fixed value in v1; distance filtering
    /// itself is free, radius selection is a candidate Plus filter later.
    private let radiusMeters: Double = 50_000

    private let activePet: Pet
    private let deckService: DeckServicing
    private let swipeService: SwipeServicing
    private let userService: UserServicing
    private let analytics: AnalyticsServicing
    private let currentUserId: () -> String?
    private let now: () -> Date

    private var user: AppUser?

    init(
        activePet: Pet,
        deckService: DeckServicing = DeckService.shared,
        swipeService: SwipeServicing = SwipeService.shared,
        userService: UserServicing = UserService.shared,
        analytics: AnalyticsServicing = AnalyticsService.shared,
        currentUserId: @escaping () -> String? = { AuthService.shared.currentUserId },
        now: @escaping () -> Date = { Date() }
    ) {
        self.activePet = activePet
        self.deckService = deckService
        self.swipeService = swipeService
        self.userService = userService
        self.analytics = analytics
        self.currentUserId = currentUserId
        self.now = now
    }

    var currentCard: DeckCard? {
        guard deck.indices.contains(topIndex) else { return nil }
        return deck[topIndex]
    }

    var nextCard: DeckCard? {
        let next = topIndex + 1
        guard deck.indices.contains(next) else { return nil }
        return deck[next]
    }

    var isDeckExhausted: Bool {
        !isLoading && topIndex >= deck.count
    }

    var isPremium: Bool { user?.isPremium ?? false }

    var remainingSwipes: Int? {
        counter().resetIfNeeded(now: now()).remainingSwipes(isPremium: isPremium)
    }

    func load() async {
        guard let uid = currentUserId() else {
            errorMessage = AuthServiceError.notSignedIn.errorDescription
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            user = try await userService.fetchUser(uid: uid)

            async let swipedIdsTask = swipeService.fetchSwipedTargetPetIds(swiperUserId: uid)
            async let superlikersTask = incomingSuperlikerPetIds()
            let center = CLLocationCoordinate2D(latitude: activePet.latitude, longitude: activePet.longitude)
            async let candidatesTask = deckService.fetchCandidates(
                center: center,
                radiusMeters: radiusMeters,
                species: activePet.species,
                purpose: nil,
                limitPerBound: 20
            )

            let swipedIds = try await swipedIdsTask
            let superlikerPetIds = await superlikersTask
            let candidates = try await candidatesTask
            let blocked = Set(user?.blockedUserIds ?? [])

            deck = candidates
                .filter { $0.ownerId != uid }
                .filter { !swipedIds.contains($0.id ?? "") }
                .filter { !blocked.contains($0.ownerId) }
                .map { pet in
                    DeckCard(
                        pet: pet,
                        distanceKm: distanceKm(to: pet),
                        isSuperlikedByTarget: superlikerPetIds.contains(pet.id ?? "")
                    )
                }
                .sorted(by: Self.rank(now: now()))
            topIndex = 0
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Handles a swipe. Enforces the free daily limit before writing anything —
    /// hitting the limit surfaces the paywall instead of recording the swipe
    /// (§12 M3 acceptance). Returns true if the swipe was recorded.
    @discardableResult
    func swipe(_ direction: Swipe.Direction) async -> Bool {
        guard let card = currentCard,
              let uid = currentUserId(),
              let activePetId = activePet.id,
              let targetPetId = card.pet.id else {
            return false
        }

        var updated = counter().resetIfNeeded(now: now())

        // Presenting the paywall logs `paywall_viewed` from PaywallViewModel.onAppear,
        // so it isn't logged here (that would double-count).
        if direction == .superlike, !updated.canSuperlike(isPremium: isPremium) {
            paywallSource = .superlikeLimit
            return false
        }
        guard updated.canSwipe(isPremium: isPremium) else {
            paywallSource = .swipeLimit
            return false
        }

        let swipe = Swipe(
            id: nil,
            swiperUserId: uid,
            swiperPetId: activePetId,
            targetPetId: targetPetId,
            targetOwnerId: card.pet.ownerId,
            direction: direction,
            timestamp: Timestamp(date: now())
        )

        do {
            try await swipeService.recordSwipe(swipe)
            updated = updated.recordingSwipe(direction: direction)
            try await userService.updateSwipeCounters(
                uid: uid,
                swipeCount: updated.swipeCount,
                superlikeCount: updated.superlikeCount,
                lastResetDate: updated.lastResetDate
            )
            applyCounter(updated)
            analytics.log(.swipePerformed(direction: direction.rawValue))
            advance()

            // Every 10th swipe, free users get a native ad card before the next pet.
            if !isPremium {
                swipesSinceAd += 1
                if swipesSinceAd >= Self.adFrequency {
                    swipesSinceAd = 0
                    showAd = true
                }
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func dismissPaywall() {
        paywallSource = nil
        analytics.log(.paywallDismissed)
    }

    func dismissAd() {
        showAd = false
    }

    // MARK: - Helpers

    private func advance() {
        topIndex += 1
    }

    private func counter() -> DailySwipeCounter {
        DailySwipeCounter(
            swipeCount: user?.dailySwipeCount ?? 0,
            superlikeCount: user?.dailySuperlikeCount ?? 0,
            lastResetDate: user?.lastSwipeResetDate.dateValue() ?? now()
        )
    }

    private func applyCounter(_ counter: DailySwipeCounter) {
        user?.dailySwipeCount = counter.swipeCount
        user?.dailySuperlikeCount = counter.superlikeCount
        user?.lastSwipeResetDate = Timestamp(date: counter.lastResetDate)
    }

    private func incomingSuperlikerPetIds() async -> Set<String> {
        guard let petId = activePet.id else { return [] }
        return (try? await swipeService.fetchIncomingSuperlikerPetIds(
            targetOwnerId: activePet.ownerId,
            targetPetId: petId
        )) ?? []
    }

    private func distanceKm(to pet: Pet) -> Double {
        let from = CLLocation(latitude: activePet.latitude, longitude: activePet.longitude)
        let to = CLLocation(latitude: pet.latitude, longitude: pet.longitude)
        return from.distance(from: to) / 1_000
    }

    /// Ordering: incoming-superlike cards first, then boosted pets, then nearest.
    private static func rank(now: Date) -> (DeckCard, DeckCard) -> Bool {
        { lhs, rhs in
            if lhs.isSuperlikedByTarget != rhs.isSuperlikedByTarget {
                return lhs.isSuperlikedByTarget
            }
            let lhsBoosted = (lhs.pet.boostedUntil?.dateValue() ?? .distantPast) > now
            let rhsBoosted = (rhs.pet.boostedUntil?.dateValue() ?? .distantPast) > now
            if lhsBoosted != rhsBoosted {
                return lhsBoosted
            }
            return lhs.distanceKm < rhs.distanceKm
        }
    }
}
