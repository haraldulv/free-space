import SwiftUI
import Supabase
import UIKit

@MainActor
final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    @Published var pendingListingId: String?
    /// Settes når brukeren klikker en e-post-verifiseringslenke. Trigger
    /// `EmailVerifiedView` som full-screen sheet i `TunoApp.body`.
    @Published var showEmailVerified = false

    /// Status for siste verifiseringsforsøk. EmailVerifiedView viser
    /// loading mens verifyOTP kjører, suksess når den lykkes, eller
    /// feilmelding hvis den feiler. Brukeren skal ikke trykke noe.
    enum VerifyStatus: Equatable {
        case verifying
        case success
        case failed(String)
    }
    @Published var verifyStatus: VerifyStatus = .verifying

    /// Siste URL appen mottok via deep link / Universal Link. Brukes til
    /// debug-overlay så vi ser at handleAuthURL faktisk kjøres.
    @Published var lastReceivedURL: String = ""

    /// Felles inngang for auth-callback-URL-er fra både SwiftUI hooks
    /// (warm launch) og AppDelegate.application(_:continue:) (cold launch).
    func handleAuthURL(_ url: URL) {
        let urlString = url.absoluteString
        print("🔗 handleAuthURL: \(urlString)")
        lastReceivedURL = urlString

        let isVerificationLink = url.path.hasPrefix("/auth/verified")
            || urlString.contains("auth/verified")
            || urlString.contains("token_hash=")
            || urlString.contains("type=signup")
            || urlString.contains("type=email")

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let tokenHash = components?.queryItems?.first(where: { $0.name == "token_hash" })?.value
        let typeString = components?.queryItems?.first(where: { $0.name == "type" })?.value ?? "signup"

        if isVerificationLink {
            verifyStatus = .verifying
            showEmailVerified = true
            print("📝 isVerificationLink=true, showEmailVerified=true, tokenHash=\(tokenHash ?? "nil")")
        }

        Task {
            if let tokenHash, !tokenHash.isEmpty {
                do {
                    if tokenHash.hasPrefix("pkce_") {
                        print("🔐 PKCE exchange starter...")
                        _ = try await supabase.auth.exchangeCodeForSession(authCode: tokenHash)
                        print("✅ PKCE exchange OK")
                    } else {
                        let otpType: EmailOTPType = {
                            switch typeString {
                            case "recovery": return .recovery
                            case "magiclink": return .magiclink
                            case "email_change", "emailChange": return .emailChange
                            case "invite": return .invite
                            default: return .signup
                            }
                        }()
                        print("🔐 verifyOTP starter...")
                        _ = try await supabase.auth.verifyOTP(tokenHash: tokenHash, type: otpType)
                        print("✅ verifyOTP OK")
                    }
                    await MainActor.run { self.verifyStatus = .success }
                } catch {
                    print("❌ Auth verify feilet: \(error)")
                    await MainActor.run {
                        self.verifyStatus = .failed(error.localizedDescription)
                    }
                }
            } else {
                do {
                    try await supabase.auth.session(from: url)
                    await MainActor.run { self.verifyStatus = .success }
                } catch {
                    await MainActor.run {
                        self.verifyStatus = .failed(error.localizedDescription)
                    }
                }
            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            PushNotificationManager.shared.handleToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Push registration failed: \(error)")
    }

    /// COLD START Universal Link: SwiftUI sin .onContinueUserActivity er
    /// upålitelig når appen launcher fra dypt-lenke. AppDelegate-handleren
    /// fanger den OG videre til DeepLinkManager.
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([any UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }
        print("❄️ Cold-start Universal Link via AppDelegate: \(url.absoluteString)")
        Task { @MainActor in
            if url.path.hasPrefix("/auth/") || url.absoluteString.contains("token_hash=") {
                DeepLinkManager.shared.handleAuthURL(url)
            } else {
                let parts = url.pathComponents
                if let i = parts.firstIndex(of: "listings"), i + 1 < parts.count {
                    DeepLinkManager.shared.pendingListingId = parts[i + 1]
                }
            }
        }
        return true
    }
}

@main
struct TunoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager()
    @StateObject private var favoritesService = FavoritesService()
    @StateObject private var deepLinkManager = DeepLinkManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var pushRouter = PushRouter.shared

    init() {
        initializeGoogleMaps()
        configureImageCache()
    }

    private func configureImageCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            directory: nil,
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoading {
                    LaunchScreen()
                } else {
                    MainTabView()
                }
            }
            .environmentObject(authManager)
            .environmentObject(favoritesService)
            .environmentObject(deepLinkManager)
            .environmentObject(localizationManager)
            .environmentObject(pushRouter)
            .environment(\.locale, localizationManager.currentLocale)
            .id(localizationManager.currentLocale.identifier)
            .tint(Color.primary600)
            .preferredColorScheme(.light)
            .onChange(of: authManager.isAuthenticated) {
                Task {
                    if authManager.isAuthenticated, let userId = authManager.currentUser?.id {
                        await favoritesService.loadFavorites(userId: userId.uuidString)
                        PushNotificationManager.shared.requestPermission()
                    } else {
                        favoritesService.favoriteIds = []
                    }
                }
            }
            .task {
                if authManager.isAuthenticated, let userId = authManager.currentUser?.id {
                    await favoritesService.loadFavorites(userId: userId.uuidString)
                    PushNotificationManager.shared.requestPermission()
                }
            }
            .onOpenURL { url in
                print("🔵 onOpenURL: \(url.absoluteString)")
                deepLinkManager.lastReceivedURL = url.absoluteString
                routeIncomingURL(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                print("🌐 onContinueUserActivity: \(url.absoluteString)")
                deepLinkManager.lastReceivedURL = url.absoluteString
                routeIncomingURL(url)
            }
            .fullScreenCover(isPresented: $deepLinkManager.showEmailVerified) {
                EmailVerifiedView()
                    .environmentObject(authManager)
                    .environmentObject(deepLinkManager)
            }
            .overlay(alignment: .top) {
                debugBar
            }
        }
        .handlesExternalEvents(matching: ["*"])
    }

    /// Synlig debug-bar øverst på skjermen så vi kan se Universal Link-status
    /// uten å åpne Xcode console. Skjules når lastReceivedURL er tom.
    @ViewBuilder
    private var debugBar: some View {
        if !deepLinkManager.lastReceivedURL.isEmpty {
            VStack(spacing: 2) {
                Text("DEBUG · status: \(statusString)")
                    .font(.system(size: 9, weight: .semibold))
                Text(deepLinkManager.lastReceivedURL.prefix(80) + (deepLinkManager.lastReceivedURL.count > 80 ? "…" : ""))
                    .font(.system(size: 8, design: .monospaced))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.85))
        }
    }

    private var statusString: String {
        switch deepLinkManager.verifyStatus {
        case .verifying: return "verifying"
        case .success: return "success"
        case .failed(let m): return "failed: \(m.prefix(30))"
        }
    }

    private func extractListingId(from url: URL) -> String? {
        let components = url.pathComponents
        guard let listingsIndex = components.firstIndex(of: "listings"),
              listingsIndex + 1 < components.count else { return nil }
        return components[listingsIndex + 1]
    }

    /// Felles routing for alle innkommende URL-er, uavhengig av scheme.
    /// onOpenURL trigget tidligere kun for custom scheme — men iOS sender
    /// HTTPS Universal Links via onOpenURL også når appen er warm-launched
    /// fra en deep link. Vi sjekker path først, ikke scheme.
    private func routeIncomingURL(_ url: URL) {
        let urlString = url.absoluteString
        let isAuthLink = url.path.hasPrefix("/auth/")
            || url.host == "auth"
            || urlString.contains("token_hash=")
            || urlString.contains("auth/verified")
        if isAuthLink {
            deepLinkManager.handleAuthURL(url)
        } else if let listingId = extractListingId(from: url) {
            deepLinkManager.pendingListingId = listingId
        }
    }
}
