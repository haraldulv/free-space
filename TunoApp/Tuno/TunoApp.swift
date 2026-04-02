import SwiftUI
import Supabase

@main
struct TunoApp: App {
    @StateObject private var authManager = AuthManager()

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
            .tint(Color.primary600)
        }
    }
}
