import SwiftUI
import Supabase
import UIKit

@MainActor
final class DeepLinkManager: ObservableObject {
    static let shared = DeepLinkManager()
    @Published var pendingListingId: String?
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

