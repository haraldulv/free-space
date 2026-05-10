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
            // PGRST116 = ingen profil-rad fantes. Skjer når e-post-signup
            // sin profile-insert ble blokkert av RLS før verifisering. Vi
            // upserter nå fra user_metadata så brukerens navn og avatar
            // blir riktig vist i UI-et fra første sekund.
            print("Failed to load profile: \(error)")
            await ensureProfileExists()
        }
        await checkHostStatus()
    }

    /// Opprett profile-rad hvis den mangler. Bruker user_metadata fra Supabase
    /// auth (som har full_name fra signUp data, eller name/picture fra OAuth).
    private func ensureProfileExists() async {
        guard let user = currentUser else { return }
        let metadata = user.userMetadata
        let fullName = metadata["full_name"]?.stringValue
            ?? metadata["name"]?.stringValue
            ?? ""
        let avatarURL = metadata["avatar_url"]?.stringValue
            ?? metadata["picture"]?.stringValue

        var payload: [String: String] = [
            "id": user.id.uuidString.lowercased(),
            "full_name": fullName,
            "terms_accepted_at": ISO8601DateFormatter().string(from: Date()),
        ]
        if let avatarURL, !avatarURL.isEmpty {
            payload["avatar_url"] = avatarURL
        }

        do {
            try await supabase.from("profiles").upsert(payload).execute()
            // Re-load profile etter upsert.
            let result: Profile = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: user.id.uuidString)
                .single()
                .execute()
                .value
            profile = result
        } catch {
            print("❌ ensureProfileExists feilet: \(error)")
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

    /// Returns true if signup succeeded (user should check email)
    func signUp(fullName: String, email: String, password: String) async -> Bool {
        self.error = nil
        do {
            let result = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": .string(fullName)],
                // Web-URL er pålitelig på alle plattformer. Supabase
                // godkjenner alltid https://-redirects til hoveddomenet
                // (custom schemes må whitelistes manuelt i Dashboard og
                // har vært upålitelig). /auth/verified-siden gjør alt
                // arbeid på klient: viser "Verifisert!"-melding +
                // "Åpne Tuno-appen"-knapp som åpner appen via custom
                // scheme + auto-trigger på iOS.
                redirectTo: URL(string: "\(AppConfig.siteURL)/auth/verified")
            )

            // Supabase returnerer ikke en eksplisitt feil hvis e-posten
            // allerede er registrert (av sikkerhetsårsaker — for å unngå
            // email enumeration). I stedet kommer en bruker tilbake med
            // tom `identities`-array. Vi sjekker på det og forteller
            // brukeren det rette i stedet for å la dem vente på en mail
            // som aldri kommer.
            if result.user.identities?.isEmpty ?? true {
                self.error = "Det finnes allerede en konto med denne e-posten. Prøv å logge inn."
                return false
            }

            // Profile insert may fail if email verification is required (RLS)
            // — that's OK, profile will be created on first sign-in
            let nowIso = ISO8601DateFormatter().string(from: Date())
            try? await supabase.from("profiles").insert([
                "id": result.user.id.uuidString.lowercased(),
                "full_name": fullName,
                "terms_accepted_at": nowIso,
            ]).execute()

            return true
        } catch {
            print("❌ SignUp error: \(error)")
            self.error = "Kunne ikke opprette konto. Prøv igjen."
            return false
        }
    }

    func signInWithGoogle(launchFlow: @escaping @Sendable (URL) async throws -> URL) async {
        self.error = nil
        do {
            try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: URL(string: "no.tuno.app://auth/callback"),
                // prompt=select_account tvinger Google til å vise konto-velgeren
                // hver gang. Uten denne husker Google forrige valg og logger
                // inn automatisk — uleselig for brukere med flere Google-kontoer.
                queryParams: [(name: "prompt", value: "select_account")],
                launchFlow: launchFlow
            )

            // Google leverer fullt navn + profilbilde i user_metadata.
            // Upsert profilen så verten får navn + bilde i appen — MEN bare
            // sett avatar_url hvis brukeren ikke allerede har lastet opp et
            // eget bilde via Supabase Storage. Ellers ville Google's avatar
            // overskrive brukerens valg ved hver innlogging.
            if let user = try? await supabase.auth.session.user {
                let metadata = user.userMetadata
                let fullName = metadata["full_name"]?.stringValue
                    ?? metadata["name"]?.stringValue
                let avatarURL = metadata["avatar_url"]?.stringValue
                    ?? metadata["picture"]?.stringValue
                if let fullName, !fullName.isEmpty {
                    var payload: [String: String] = [
                        "id": user.id.uuidString.lowercased(),
                        "full_name": fullName,
                    ]
                    // Sjekk eksisterende profile: behold custom avatar (Storage-URL)
                    // og bare sett Google-avatar hvis avatar_url er nil/tom.
                    let existingAvatar = await currentAvatarUrl(userId: user.id.uuidString)
                    if let avatarURL, !avatarURL.isEmpty,
                       (existingAvatar?.isEmpty ?? true) {
                        payload["avatar_url"] = avatarURL
                    }
                    try? await supabase.from("profiles").upsert(payload).execute()
                    // Refresh in-memory profile fordi auth-listeneren
                    // kjørte loadProfile() før vi rakk å upserte.
                    await loadProfile()
                }
            }
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
                    // Refresh in-memory profile fordi auth-listeneren
                    // kjørte loadProfile() før vi rakk å upserte.
                    await loadProfile()
                }
            }
        } catch {
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                self.error = "Apple-innlogging feilet"
            }
        }
    }

    // MARK: - Vipps Sign In
    //
    // Vipps er ikke en innebygd Supabase-provider, så vi rir på vår egen
    // web-route /api/auth/vipps/start med ?native=1. Den fullfører Vipps
    // OIDC-flow server-side, oppretter/slår opp Supabase-bruker via
    // service-role, og returnerer et engangs token_hash til appen via
    // custom-scheme-redirect (no.tuno.app://vipps-return). Vi veksler det
    // med supabase.auth.verifyOTP(.magiclink) for å få session.

    func signInWithVipps(launchFlow: @escaping @Sendable (URL) async throws -> URL) async {
        self.error = nil
        guard let startURL = URL(string: "\(AppConfig.siteURL)/api/auth/vipps/start?native=1&return=/") else {
            self.error = "Vipps-innlogging feilet"
            return
        }
        do {
            let callbackURL = try await launchFlow(startURL)
            guard let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
                self.error = "Vipps-innlogging feilet"
                return
            }
            let items = comps.queryItems ?? []
            if let errParam = items.first(where: { $0.name == "error" })?.value {
                self.error = "Vipps: \(errParam)"
                return
            }
            guard let tokenHash = items.first(where: { $0.name == "token_hash" })?.value,
                  !tokenHash.isEmpty else {
                self.error = "Vipps-innlogging feilet"
                return
            }
            _ = try await supabase.auth.verifyOTP(tokenHash: tokenHash, type: .magiclink)
            await loadProfile()
        } catch {
            // ASWebAuthenticationSession kaster .canceledLogin når brukeren
            // lukker sheet'et — ikke vis feilmelding for det.
            let nsErr = error as NSError
            if nsErr.domain == "com.apple.AuthenticationServices.WebAuthenticationSession",
               nsErr.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                return
            }
            self.error = "Vipps-innlogging feilet"
        }
    }

    // MARK: - Vipps nin-flyt (Fase 3, Bli utleier)
    //
    // ASWebAuthenticationSession deler ikke session-cookies med native, så
    // vi kan ikke lene oss på SSR-session-cookien i callback-ruten. I
    // stedet:
    //  1) Appen kaller POST /api/auth/vipps/native-intent med Bearer-token.
    //     Serveren validerer sesjonen og lagrer (user_id, "nin") i
    //     `vipps_native_intents`, returnerer engangs-uuid.
    //  2) Appen åpner /api/auth/vipps/start?native=1&purpose=nin&intent=<uuid>
    //     i ASWebAuthenticationSession. Vipps OIDC kjører.
    //  3) Callback-ruten leser intent-cookien, slår opp user_id, sender data
    //     direkte til Stripe Connect, og redirecter til
    //     no.tuno.app://vipps-nin-return?status=ok|error=<reason>.
    //
    // Returnerer true hvis Stripe-oppdateringen lyktes.
    @discardableResult
    func fetchNinFromVipps(launchFlow: @escaping @Sendable (URL) async throws -> URL) async -> Bool {
        self.error = nil
        do {
            let session = try await supabase.auth.session
            let accessToken = session.accessToken

            // 1) Opprett native-intent.
            guard let intentURL = URL(string: "\(AppConfig.siteURL)/api/auth/vipps/native-intent") else {
                self.error = "Vipps-flyten feilet"
                return false
            }
            var req = URLRequest(url: intentURL)
            req.httpMethod = "POST"
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: ["purpose": "nin"])

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let intent = json["intent"] as? String else {
                self.error = "Vipps-flyten feilet"
                return false
            }

            // 2) Start Vipps i web-auth-session.
            var startComps = URLComponents(string: "\(AppConfig.siteURL)/api/auth/vipps/start")!
            startComps.queryItems = [
                URLQueryItem(name: "native", value: "1"),
                URLQueryItem(name: "purpose", value: "nin"),
                URLQueryItem(name: "intent", value: intent),
                URLQueryItem(name: "return", value: "/"),
            ]
            guard let startURL = startComps.url else {
                self.error = "Vipps-flyten feilet"
                return false
            }
            let callbackURL = try await launchFlow(startURL)

            // 3) Tolk callback.
            let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)
            let items = comps?.queryItems ?? []
            if let errParam = items.first(where: { $0.name == "error" })?.value {
                self.error = "Vipps: \(errParam)"
                return false
            }
            if items.first(where: { $0.name == "status" })?.value == "ok" {
                return true
            }
            self.error = "Vipps-flyten feilet"
            return false
        } catch {
            let nsErr = error as NSError
            if nsErr.domain == "com.apple.AuthenticationServices.WebAuthenticationSession",
               nsErr.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                return false
            }
            self.error = "Vipps-flyten feilet"
            return false
        }
    }

    /// Henter eksisterende avatar_url for brukeren slik at OAuth-login ikke
    /// overskriver et brukervalgt bilde.
    private func currentAvatarUrl(userId: String) async -> String? {
        struct Row: Decodable { let avatar_url: String? }
        do {
            let rows: [Row] = try await supabase
                .from("profiles")
                .select("avatar_url")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            return rows.first?.avatar_url
        } catch {
            return nil
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

    @Published var hasListings = false

    var isHost: Bool {
        profile?.stripeOnboardingComplete == true || hasListings
    }

    var displayName: String {
        profile?.fullName ?? currentUser?.email ?? "Bruker"
    }

    func checkHostStatus() async {
        guard let userId = currentUser?.id else { return }
        do {
            let count: Int = try await supabase
                .from("listings")
                .select("id", head: true, count: .exact)
                .eq("host_id", value: userId.uuidString.lowercased())
                .execute()
                .count ?? 0
            hasListings = count > 0
        } catch {
            print("Failed to check host status: \(error)")
        }
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
