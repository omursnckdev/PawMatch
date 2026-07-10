import FirebaseFirestore
import Foundation

final class UserService: UserServicing {
    static let shared = UserService()

    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func userDocument(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    func fetchUser(uid: String) async throws -> AppUser? {
        let snapshot = try await userDocument(uid).getDocument()
        return try snapshot.data(as: AppUser.self)
    }

    func createUserIfNeeded(uid: String, displayName: String, email: String?, authProvider: AppUser.AuthProvider) async throws {
        let ref = userDocument(uid)
        let snapshot = try await ref.getDocument()
        guard !snapshot.exists else { return }

        let user = AppUser(
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
        try ref.setData(from: user)
    }

    func confirmAge(uid: String) async throws {
        try await userDocument(uid).updateData(["isAgeConfirmed": true])
    }
}
