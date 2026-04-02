import Foundation
import Supabase

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
