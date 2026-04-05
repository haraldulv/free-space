import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedTab = 0
    @State private var deepLinkListingId: String?

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
        .onReceive(NotificationCenter.default.publisher(for: .openListing)) { notification in
            if let id = notification.userInfo?["listingId"] as? String {
                selectedTab = 0
                deepLinkListingId = id
            }
        }
        .sheet(item: $deepLinkListingId) { listingId in
            NavigationStack {
                ListingDetailView(listingId: listingId)
            }
        }
    }
}

extension Notification.Name {
    static let switchToBookingsTab = Notification.Name("switchToBookingsTab")
}
