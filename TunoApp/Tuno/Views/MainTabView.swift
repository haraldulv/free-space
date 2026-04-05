import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager
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

            Tab("Bestillinger", systemImage: "calendar.badge.checkmark", value: 2) {
                NavigationStack {
                    BookingsView()
                }
            }

            Tab("Meldinger", systemImage: "bubble.left", value: 3) {
                NavigationStack {
                    MessagesListView()
                }
            }

            Tab("Profil", systemImage: "person.crop.circle", value: 4) {
                NavigationStack {
                    ProfileView()
                }
            }
        }
        .tint(.primary600)
        .onReceive(NotificationCenter.default.publisher(for: .switchToBookingsTab)) { _ in
            selectedTab = 2
        }
        .sheet(item: $deepLinkManager.pendingListingId) { listingId in
            NavigationStack {
                ListingDetailView(listingId: listingId)
            }
        }
    }
}

extension Notification.Name {
    static let switchToBookingsTab = Notification.Name("switchToBookingsTab")
}
