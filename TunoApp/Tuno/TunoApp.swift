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
                Task {
                    try? await supabase.auth.session(from: url)
                }
            }
        }
    }
}
