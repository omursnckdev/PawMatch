import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

/// Owns push-notification permission and FCM token syncing. The OS permission
/// prompt is preceded by an in-app priming screen in onboarding (§9); this
/// service only fires the actual system request.
@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    /// The most recent FCM token, cached so it can be uploaded once the user is
    /// known (the token can arrive before or after sign-in).
    private(set) var fcmToken: String?

    private let userService: UserServicing
    private let currentUserId: () -> String?

    init(
        userService: UserServicing = UserService.shared,
        currentUserId: @escaping () -> String? = { AuthService.shared.currentUserId }
    ) {
        self.userService = userService
        self.currentUserId = currentUserId
    }

    /// Presents the system notification prompt and registers for remote
    /// notifications. Returns whether permission was granted.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            return false
        }
    }

    /// Called by the AppDelegate's Messaging delegate whenever a token arrives.
    func handleTokenRefresh(_ token: String) {
        fcmToken = token
        Task { await syncToken() }
    }

    /// Uploads the cached token to the signed-in user's document. Safe to call
    /// repeatedly (e.g. after sign-in and on every refresh).
    func syncToken() async {
        guard let token = fcmToken, let uid = currentUserId() else { return }
        try? await userService.updateFCMToken(uid: uid, token: token)
    }
}
