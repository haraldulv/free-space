import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @State private var selectedTab = 0
    @State private var homeNavPath = NavigationPath()

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content area
            Group {
                switch selectedTab {
                case 0:
                    NavigationStack(path: $homeNavPath) {
                        HomeView()
                    }
                case 1:
                    NavigationStack {
                        FavoritesView()
                    }
                case 2:
                    NavigationStack {
                        BookingsView()
                    }
                case 3:
                    NavigationStack {
                        MessagesListView()
                    }
                case 4:
                    NavigationStack {
                        ProfileView()
                    }
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 56)

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: .switchToBookingsTab)) { _ in
            selectedTab = 2
            homeNavPath = NavigationPath()
            deepLinkManager.pendingListingId = nil
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
