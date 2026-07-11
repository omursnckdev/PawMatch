import FirebaseAppCheck
import FirebaseCore
import FirebaseCrashlytics
import FirebaseMessaging
import GoogleMobileAds
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Must run before FirebaseApp.configure() so App Check attaches to every
        // Firebase service from the first request (§5 — App Check is not optional).
        AppCheck.setAppCheckProviderFactory(PawMatchAppCheckProviderFactory())

        FirebaseApp.configure()

        // Crashlytics collection is enabled by default once the SDK is linked;
        // this call makes the intent explicit and lets it be toggled by a user
        // privacy setting later without hunting for the call site.
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        // Monetization SDKs (§8). RevenueCat is associated with the Firebase uid
        // on sign-in (see RootView); AdMob starts its mediation here.
        PurchaseService.shared.configure()
        MobileAds.shared.start(completionHandler: nil)

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

// MARK: - FCM token

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in
            NotificationService.shared.handleTokenRefresh(fcmToken)
        }
    }
}

// MARK: - Notification presentation & taps

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Show the banner even when the app is foregrounded.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    // Tapping a match/message push deep-links into that conversation (§7 item 3).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let matchId = userInfo["matchId"] as? String {
            Task { @MainActor in
                DeepLinkRouter.shared.openChat(matchId: matchId)
            }
        }
        completionHandler()
    }
}
