import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

struct AppleSignInPayload {
    let idTokenString: String
    let rawNonce: String
    let fullName: PersonNameComponents?
}

enum AppleSignInError: LocalizedError {
    case missingIdentityToken
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .missingIdentityToken:
            return "Apple didn't return an identity token. Please try again."
        case .userCancelled:
            return nil
        }
    }
}

protocol AppleSignInCoordinating {
    @MainActor
    func signIn() async throws -> AppleSignInPayload
}

/// Bridges `ASAuthorizationController`'s delegate-based API into async/await and
/// generates the SHA256-hashed nonce Firebase Auth requires for Sign in with Apple.
@MainActor
final class AppleSignInCoordinator: NSObject, AppleSignInCoordinating {
    private var continuation: CheckedContinuation<AppleSignInPayload, Error>?
    private var currentRawNonce: String?

    func signIn() async throws -> AppleSignInPayload {
        let rawNonce = Self.randomNonceString()
        currentRawNonce = rawNonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randomByte: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &randomByte)
            guard status == errSecSuccess else { continue }
            if randomByte < charset.count {
                result.append(charset[Int(randomByte)])
                remainingLength -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { continuation = nil }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idTokenString = String(data: tokenData, encoding: .utf8),
              let rawNonce = currentRawNonce else {
            continuation?.resume(throwing: AppleSignInError.missingIdentityToken)
            return
        }

        let payload = AppleSignInPayload(
            idTokenString: idTokenString,
            rawNonce: rawNonce,
            fullName: credential.fullName
        )
        continuation?.resume(returning: payload)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        defer { continuation = nil }

        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: AppleSignInError.userCancelled)
        } else {
            continuation?.resume(throwing: error)
        }
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return ASPresentationAnchor()
        }
        return window
    }
}
