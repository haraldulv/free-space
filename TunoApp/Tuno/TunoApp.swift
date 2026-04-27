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

    /// Stor disk-cache for listing-bilder og avatarer. URLSession bruker denne via
    /// `URLCache.shared`, og `CachedAsyncImage` leser fra den før nettkall.
    private func configureImageCache() {
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50 MB RAM
            diskCapacity: 500 * 1024 * 1024,    // 500 MB disk
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
                if url.scheme == "no.tuno.app" {
                    handleAuthURL(url)
                } else {
                    if let listingId = extractListingId(from: url) {
                        deepLinkManager.pendingListingId = listingId
                    }
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                // /auth/verified åpner verifiserings-sheet med auto-login
                // fra hash-tokens. /listings/* har vanlig dyp lenke.
                if url.path.hasPrefix("/auth/verified") {
                    handleAuthURL(url)
                } else if let listingId = extractListingId(from: url) {
                    deepLinkManager.pendingListingId = listingId
                }
            }
            .fullScreenCover(isPresented: $deepLinkManager.showEmailVerified) {
                EmailVerifiedView()
                    .environmentObject(authManager)
            }
        }
    }

    /// Felles inngang for alle auth-callback-URL-er, både custom scheme
    /// (`no.tuno.app://auth/...`) og Universal Links (`tuno.no/auth/verified`).
    /// Sender URL-en gjennom `supabase.auth.session(from:)` så tokens i
    /// hash-fragmentet logger brukeren inn, og åpner verifiserings-sheetet
    /// hvis dette var en e-post-bekreftelse.
    private func handleAuthURL(_ url: URL) {
        let isVerificationLink = url.path.hasPrefix("/auth/verified")
            || url.absoluteString.contains("type=signup")
            || url.absoluteString.contains("type=email")
        Task {
            try? await supabase.auth.session(from: url)
            if isVerificationLink {
                await MainActor.run {
                    deepLinkManager.showEmailVerified = true
                }
            }
        }
    }

    private func extractListingId(from url: URL) -> String? {
        // URL format: tuno.no/listings/{id}
        let components = url.pathComponents
        guard let listingsIndex = components.firstIndex(of: "listings"),
              listingsIndex + 1 < components.count else { return nil }
        return components[listingsIndex + 1]
    }
}

