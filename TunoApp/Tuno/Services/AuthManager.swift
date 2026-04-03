import Foundation
import Supabase
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = true
    @Published var currentUser: User?
    @Published var profile: Profile?
    @Published var error: String?

    init() {
        Task {
            await checkSession()
            listenToAuthChanges()
        }
    }

    private func checkSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isAuthenticated = true
            await loadProfile()
        } catch {
            isAuthenticated = false
            currentUser = nil
        }
        isLoading = false
    }

    private func listenToAuthChanges() {
        Task {
            for await (event, session) in supabase.auth.authStateChanges {
                switch event {
                case .signedIn:
                    currentUser = session?.user
                    isAuthenticated = true
                    await loadProfile()
                case .signedOut:
                    currentUser = nil
                    profile = nil
                    isAuthenticated = false
                default:
                    break
                }
            }
        }
    }

    func loadProfile() async {
        guard let userId = currentUser?.id else { return }
        do {
            let result: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId.uuidString)
                .single()
                .execute()
                .value
            profile = result
        } catch {
            print("Failed to load profile: \(error)")
        }
    }

    // MARK: - Email/Password Auth

    func signIn(email: String, password: String) async {
        self.error = nil
        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            currentUser = session.user
            isAuthenticated = true
            await loadProfile()
        } catch {
            self.error = "Feil e-post eller passord"
        }
    }

    func signUp(fullName: String, email: String, password: String) async {
        self.error = nil
        do {
            let result = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)]
            )
            let user = result.user

            // Create profile
            try await supabase.from("profiles").insert([
                "id": user.id.uuidString,
                "full_name": fullName,
            ]).execute()

            currentUser = user
            isAuthenticated = true
            await loadProfile()
        } catch {
            self.error = "Kunne ikke opprette konto. Prøv igjen."
        }
    }

    func signInWithGoogle(launchFlow: @escaping @Sendable (URL) async throws -> URL) async {
        self.error = nil
        do {
            try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "no.tuno.app://auth/callback"),
                launchFlow: launchFlow
            )
        } catch {
            self.error = "Google-innlogging feilet"
        }
    }

    // MARK: - Apple Sign In

    func signInWithApple() async {
        self.error = nil
        do {
            let helper = AppleSignInHelper()
            let credential = try await helper.performSignIn()

            try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: credential.idToken,
                    nonce: credential.nonce
                )
            )

            // Create profile if it doesn't exist
            if let user = try? await supabase.auth.session.user {
                let fullName = credential.fullName
                if let fullName, !fullName.isEmpty {
                    try? await supabase.from("profiles").upsert([
                        "id": user.id.uuidString,
                        "full_name": fullName,
                    ]).execute()
                }
            }
        } catch {
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                self.error = "Apple-innlogging feilet"
            }
        }
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        currentUser = nil
        profile = nil
        isAuthenticated = false
    }

    func resetPassword(email: String) async -> Bool {
        do {
            try await supabase.auth.resetPasswordForEmail(email)
            return true
        } catch {
            self.error = "Kunne ikke sende tilbakestillingslenke"
            return false
        }
    }

    var isHost: Bool {
        profile?.stripeOnboardingComplete == true
    }

    var displayName: String {
        profile?.fullName ?? currentUser?.email ?? "Bruker"
    }
}

// MARK: - Apple Sign In Helper

struct AppleSignInCredential {
    let idToken: String
    let nonce: String
    let fullName: String?
}

class AppleSignInHelper: NSObject, ASAuthorizationControllerDelegate {
    private var continuation: CheckedContinuation<AppleSignInCredential, Error>?
    private var nonce: String = ""

    func performSignIn() async throws -> AppleSignInCredential {
        nonce = randomNonceString()
        let hashedNonce = sha256(nonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Missing token"]))
            return
        }

        var fullName: String?
        if let nameComponents = credential.fullName {
            let parts = [nameComponents.givenName, nameComponents.familyName].compactMap { $0 }
            if !parts.isEmpty {
                fullName = parts.joined(separator: " ")
            }
        }

        continuation?.resume(returning: AppleSignInCredential(idToken: idToken, nonce: nonce, fullName: fullName))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuation?.resume(throwing: error)
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                precondition(status == errSecSuccess)
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
