import SwiftUI
import Supabase

@main
struct TunoApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoading {
                    LaunchScreen()
                } else if authManager.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .tint(Color.primary600)
        }
    }
}
