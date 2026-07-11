import FirebaseFirestore
import Foundation

/// The single client-side source for "is this user Plus?" gating. It listens to
/// the user's Firestore document, whose `isPremium` is written **only** by the
/// RevenueCat webhook (§8) — so the client never self-grants entitlement. After
/// a successful purchase the paywall calls `applyOptimisticPremium()` so Plus UI
/// unlocks immediately while the webhook write propagates.
@MainActor
final class EntitlementManager: ObservableObject {
    static let shared = EntitlementManager()

    @Published private(set) var isPremium = false
    @Published private(set) var billingIssue = false

    private var listener: ListenerRegistration?

    // Firestore is resolved lazily inside `start()` so this type can be
    // constructed in unit tests without a configured FirebaseApp.
    func start(uid: String) {
        listener?.remove()
        listener = Firestore.firestore().collection("users").document(uid).addSnapshotListener { [weak self] snapshot, _ in
            guard let self, let data = snapshot?.data() else { return }
            Task { @MainActor in
                self.isPremium = data["isPremium"] as? Bool ?? false
                self.billingIssue = data["billingIssue"] as? Bool ?? false
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        isPremium = false
        billingIssue = false
    }

    func applyOptimisticPremium() {
        isPremium = true
    }
}
