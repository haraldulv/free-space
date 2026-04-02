import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Utforsk", systemImage: "magnifyingglass", value: 0) {
                NavigationStack {
                    HomeView()
                }
            }

            Tab("Favoritter", systemImage: "heart", value: 1) {
                NavigationStack {
                    FavoritesView()
                }
            }

            Tab("Bestillinger", systemImage: "calendar", value: 2) {
                NavigationStack {
                    BookingsView()
                }
            }

            Tab("Meldinger", systemImage: "message", value: 3) {
                NavigationStack {
                    MessagesListView()
                }
            }

            Tab("Profil", systemImage: "person", value: 4) {
                NavigationStack {
                    ProfileView()
                }
            }
        }
        .tint(.primary600)
    }
}
