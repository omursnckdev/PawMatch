import FirebaseAppCheck
import FirebaseCore
import FirebaseCrashlytics
import UIKit

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

        return true
    }
}
