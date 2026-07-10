//
//  AuthService.swift
//  chat-ios
//
//  Avagenc authentication: Google Sign-In (GoogleSignIn SDK) → FirebaseAuth.
//  The backend only verifies the Firebase ID token (Authorization: Bearer);
//  session persistence & token refresh are handled by the Firebase SDK.
//

import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import UIKit

struct UserProfile: Equatable {
    var name: String
    var email: String

    var initial: String {
        String(name.first ?? "H").uppercased()
    }

    static func derive(displayName: String?, email: String?) -> UserProfile {
        // name = displayName → email → "Human"
        let name = (displayName?.isEmpty == false ? displayName : nil)
            ?? (email?.isEmpty == false ? email : nil)
            ?? "Human"
        return UserProfile(name: name, email: email ?? "")
    }
}

enum AuthError: LocalizedError {
    case notConfigured
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Firebase belum terkonfigurasi — pastikan GoogleService-Info.plist ada di target."
        case .cancelled:
            "Login dibatalkan."
        case .failed(let msg):
            msg
        }
    }
}

@Observable
final class AuthService: APICredentialProvider {
    private(set) var profile: UserProfile?
    /// Holds rendering until the persisted session has been restored.
    private(set) var ready = false

    var authed: Bool { profile != nil }

    init() {
        // Firebase restores the session from the keychain; currentUser is
        // usually available synchronously, but the `ready` gate waits for the
        // listener's first callback so the Login screen never flashes.
        if FirebaseApp.app() != nil {
            if let user = Auth.auth().currentUser {
                profile = .derive(displayName: user.displayName, email: user.email)
            }
            Auth.auth().addStateDidChangeListener { [weak self] _, user in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.profile = user.map {
                        .derive(displayName: $0.displayName, email: $0.email)
                    }
                    self.ready = true
                }
            }
        } else {
            ready = true
        }
    }

    // MARK: - APICredentialProvider

    func bearerToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw ApiError(status: 401, detail: "not authenticated")
        }
        // The SDK refreshes automatically as the token nears expiry.
        return try await user.idTokenForcingRefresh(false)
    }

    // MARK: - Login / logout

    /// Google Sign-In → Firebase credential. The client ID comes from
    /// GoogleService-Info.plist via FirebaseApp options.
    func loginWithGoogle(presenting: UIViewController) async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.notConfigured
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        } catch let e as GIDSignInError where e.code == .canceled {
            throw AuthError.cancelled
        } catch {
            throw AuthError.failed("Gagal masuk. Coba lagi.")
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.failed("Gagal masuk. Coba lagi.")
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        profile = .derive(
            displayName: authResult.user.displayName,
            email: authResult.user.email
        )
    }

    func logout() {
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
        profile = nil
    }
}
