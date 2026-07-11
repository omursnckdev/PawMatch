import FirebaseFirestore

/// Mirrors a document at `users/{userId}`.
///
/// `isPremium` is written only by the `revenueCatWebhook` Cloud Function; Firestore
/// security rules must reject client writes to that field (see firestore.rules).
struct AppUser: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    var displayName: String
    var email: String?
    var authProvider: AuthProvider
    var isPremium: Bool
    var billingIssue: Bool
    var dailySwipeCount: Int
    var dailySuperlikeCount: Int
    var lastSwipeResetDate: Timestamp
    var fcmToken: String?
    var blockedUserIds: [String]
    var isAgeConfirmed: Bool
    var createdAt: Timestamp

    enum AuthProvider: String, Codable {
        case apple
        case email
    }
}
