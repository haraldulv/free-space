import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var deepLinkManager: DeepLinkManager
    @EnvironmentObject var pushRouter: PushRouter
    @StateObject private var chatService = ChatService()
    @StateObject private var profileStats = ProfileStatsStore()
    @State private var selectedTab = 0
    @State private var homeNavPath = NavigationPath()
    @State private var messagesNavPath = NavigationPath()
    @State private var pendingHostRequests: Int = 0

    var body: some View {
        // Bruk safeAreaInset i stedet for ZStack + magic-number-padding.
        // SwiftUI plasserer tab-baren som en bunn-inset som tidligere versjoner
        // simulerte med .padding(.bottom, 80). Magic-nummeret matchet ikke
        // tab-barens faktiske høyde eksakt → 1-2pt hvit stripe mellom content
        // og tab-bar. Med safeAreaInset håndterer SwiftUI målingen automatisk.
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
                NavigationStack(path: $messagesNavPath) {
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(
                selectedTab: $selectedTab,
                unreadMessages: chatService.unreadCount,
                pendingHostRequests: pendingHostRequests,
                profileAvatarURL: authManager.profile?.avatarUrl.flatMap(URL.init(string:)),
                profileInitial: profileInitial,
            )
        }
        .environmentObject(chatService)
        .environmentObject(profileStats)
        .ignoresSafeArea(.keyboard)
        .task {
            await loadUnreadCount()
            await loadPendingHostRequests()
            await refreshProfileStats()
        }
        .onChange(of: authManager.currentUser?.id) { _, _ in
            Task { await refreshProfileStats() }
        }
        .onChange(of: selectedTab) { _, newTab in
            // Refresh unread count when leaving messages tab
            if newTab != 3 {
                Task { await loadUnreadCount() }
            }
            // Refresh pending-count når vi forlater Profil-tab (etter at host svarte)
            if newTab != 4 {
                Task { await loadPendingHostRequests() }
            }
            // Refresh profil-stats i bakgrunnen når vi går INN på Profil-tab —
            // cached verdier vises umiddelbart, nye verdier kommer inn uten flicker.
            if newTab == 4 {
                Task { await refreshProfileStats() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToBookingsTab)) { _ in
            selectedTab = 2
            homeNavPath = NavigationPath()
            deepLinkManager.pendingListingId = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .newPushNotification)) { _ in
            Task {
                await loadUnreadCount()
                await loadPendingHostRequests()
            }
        }
        .onChange(of: pushRouter.pendingBookingId) { _, newValue in
            guard newValue != nil else { return }
            // booking_request → Profile-tab (HostRequestsView pluker det opp).
            // Andre typer → Bookings-tab (gjest-flyt).
            if pushRouter.pendingBookingType == "booking_request" {
                selectedTab = 4
            } else {
                selectedTab = 2
                homeNavPath = NavigationPath()
            }
        }
        .onChange(of: pushRouter.pendingConversationId) { _, newValue in
            guard let id = newValue else { return }
            selectedTab = 3
            messagesNavPath = NavigationPath()
            messagesNavPath.append(id)
            pushRouter.clearConversation()
        }
        .sheet(item: $deepLinkManager.pendingListingId) { listingId in
            NavigationStack {
                ListingDetailView(listingId: listingId)
            }
        }
    }

    private var profileInitial: String? {
        let name = authManager.profile?.fullName?.trimmingCharacters(in: .whitespaces)
        if let name, let first = name.first {
            return String(first).uppercased()
        }
        if let email = authManager.currentUser?.email, let first = email.first {
            return String(first).uppercased()
        }
        return nil
    }

    private func loadUnreadCount() async {
        guard let userId = authManager.currentUser?.id else { return }
        await chatService.loadConversations(userId: userId.uuidString.lowercased())
    }

    private func refreshProfileStats() async {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased() else {
            profileStats.clear()
            return
        }
        await profileStats.refresh(userId: userId, isHost: authManager.isHost)
    }

    private func loadPendingHostRequests() async {
        guard let userId = authManager.currentUser?.id.uuidString.lowercased(),
              authManager.isHost else {
            pendingHostRequests = 0
            return
        }
        do {
            let count = try await supabase
                .from("bookings")
                .select("id", head: true, count: .exact)
                .eq("host_id", value: userId)
                .eq("status", value: "requested")
                .execute()
                .count ?? 0
            pendingHostRequests = count
        } catch {
            print("loadPendingHostRequests error: \(error)")
        }
    }
}

extension Notification.Name {
    static let switchToBookingsTab = Notification.Name("switchToBookingsTab")
    // newPushNotification is defined in PushNotificationManager.swift
}
