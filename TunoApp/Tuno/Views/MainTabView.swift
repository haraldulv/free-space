import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @EnvironmentObject var pushRouter: PushRouter
    @StateObject private var chatService = ChatService()
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
            CustomTabBar(selectedTab: $selectedTab, unreadMessages: chatService.unreadCount)
        }
        .ignoresSafeArea(.keyboard)
        .task {
            await loadUnreadCount()
        }
        .onChange(of: selectedTab) { _, newTab in
            // Refresh unread count when leaving messages tab
            if newTab != 3 {
                Task { await loadUnreadCount() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToBookingsTab)) { _ in
            selectedTab = 2
            homeNavPath = NavigationPath()
            deepLinkManager.pendingListingId = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .newPushNotification)) { _ in
            Task { await loadUnreadCount() }
        }
        .onChange(of: pushRouter.pendingBookingId) { _, newValue in
            guard newValue != nil else { return }
            // Bytt til bookings-tab ved tap på booking-relatert varsel
            selectedTab = 2
            homeNavPath = NavigationPath()
            // BookingsView kan plukke opp ID-en selv når den laster
        }
        .onChange(of: pushRouter.pendingConversationId) { _, newValue in
            guard newValue != nil else { return }
            selectedTab = 3
        }
        .sheet(item: $deepLinkManager.pendingListingId) { listingId in
            NavigationStack {
                ListingDetailView(listingId: listingId)
            }
        }
    }

    private func loadUnreadCount() async {
        guard let userId = authManager.currentUser?.id else { return }
        await chatService.loadConversations(userId: userId.uuidString.lowercased())
    }
}

extension Notification.Name {
    static let switchToBookingsTab = Notification.Name("switchToBookingsTab")
    // newPushNotification is defined in PushNotificationManager.swift
}
