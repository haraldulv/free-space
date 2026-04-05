import SwiftUI
import Supabase

@main
struct TunoApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var favoritesService = FavoritesService()

    init() {
        initializeGoogleMaps()
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
            .tint(Color.primary600)
            .preferredColorScheme(.light)
            .onChange(of: authManager.isAuthenticated) {
                Task {
                    if authManager.isAuthenticated, let userId = authManager.currentUser?.id {
                        await favoritesService.loadFavorites(userId: userId.uuidString)
                    } else {
                        favoritesService.favoriteIds = []
                    }
                }
            }
            .task {
                if authManager.isAuthenticated, let userId = authManager.currentUser?.id {
                    await favoritesService.loadFavorites(userId: userId.uuidString)
                }
            }
            .onOpenURL { url in
                if url.scheme == "no.tuno.app" && url.host == "stripe" {
                    NotificationCenter.default.post(name: .stripeOnboardingComplete, object: nil)
                } else if url.scheme == "no.tuno.app" {
                    Task {
                        try? await supabase.auth.session(from: url)
                    }
                } else {
                    // Universal Link — e.g. tuno.no/listings/abc123?spot=1
                    if let listingId = extractListingId(from: url) {
                        NotificationCenter.default.post(
                            name: .openListing,
                            object: nil,
                            userInfo: ["listingId": listingId]
                        )
                    }
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

extension Notification.Name {
    static let openListing = Notification.Name("openListing")
}
