import SwiftUI
import Supabase

@MainActor
final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    @Published var pendingListingId: String?
}

@main
struct TunoApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var favoritesService = FavoritesService()
    @StateObject private var deepLinkManager = DeepLinkManager.shared

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
            .environmentObject(deepLinkManager)
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
                    if let listingId = extractListingId(from: url) {
                        deepLinkManager.pendingListingId = listingId
                    }
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                if let url = activity.webpageURL,
                   let listingId = extractListingId(from: url) {
                    deepLinkManager.pendingListingId = listingId
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

