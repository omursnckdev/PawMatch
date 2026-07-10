import Firebase
import FirebaseAppCheck

/// Uses App Attest on device, falling back to Debug provider only in DEBUG builds
/// so local development doesn't require a real device/attestation.
///
/// Must be installed via `AppCheck.setAppCheckProviderFactory(_:)` **before**
/// `FirebaseApp.configure()` is called — see `AppDelegate`.
final class PawMatchAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}
