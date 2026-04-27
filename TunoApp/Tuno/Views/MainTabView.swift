import SwiftUI
import UIKit

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
    /// Avatar lastet og beskåret til sirkel — brukes som Profil-tab-ikon.
    /// Re-lastes når URL endres. Fall tilbake til outline-SF-symbol hvis ingen URL.
    @State private var profileTabImage: UIImage? = nil

    /// Helper: hent outline-versjon av et SF Symbol som konkret UIImage.
    /// iOS kan ikke substituere .fill når vi sender ferdig UIImage til tabItem.
    /// 18pt matcher TunoPinTab (24pt asset → ~18pt visuell vekt) for konsistent størrelse.
    private static func outlineIcon(_ name: String) -> Image {
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        let img = UIImage(systemName: name, withConfiguration: cfg) ?? UIImage()
        return Image(uiImage: img.withRenderingMode(.alwaysTemplate))
    }

    /// Last avatar fra URL → UIImage, beskår til sirkel, sett i profileTabImage.
    /// Kjøres når URL endres eller ved første render.
    private func loadProfileTabImage() async {
        guard let urlString = authManager.profile?.avatarUrl,
              let url = URL(string: urlString) else {
            profileTabImage = nil
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let uiImage = UIImage(data: data) else { return }
            // Resize + clip til sirkel — gir ferdig "static" tab-ikon.
            let size: CGFloat = 26
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            let circleImage = renderer.image { ctx in
                let rect = CGRect(x: 0, y: 0, width: size, height: size)
                UIBezierPath(ovalIn: rect).addClip()
                uiImage.draw(in: rect)
            }
            // Bruk .alwaysOriginal så iOS ikke tinter den med tab-bar farge.
            profileTabImage = circleImage.withRenderingMode(.alwaysOriginal)
        } catch {
            profileTabImage = nil
        }
    }

    var body: some View {
        // Standard SwiftUI TabView. iOS 17+ gir liquid glass / blur-bakgrunn
        // automatisk, og safe-area håndteres uten manuell padding på child-views.
        // Tidligere brukte vi en custom HStack med PreferenceKey-padding;
        // ryddet bort fordi den hadde flere safe-area-bugs (build 55-58).
        TabView(selection: $selectedTab) {
            NavigationStack(path: $homeNavPath) {
                HomeView()
            }
            .tabItem { Label { Text("Utforsk") } icon: { Self.outlineIcon("magnifyingglass") } }
            .tag(0)

            NavigationStack {
                FavoritesView()
            }
            .tabItem { Label { Text("Favoritter") } icon: { Self.outlineIcon("heart") } }
            .tag(1)

            NavigationStack {
                BookingsView()
            }
            .tabItem {
                Label {
                    Text("Bestillinger")
                } icon: {
                    Image("TunoPinTab")
                }
            }
            .tag(2)

            NavigationStack(path: $messagesNavPath) {
                MessagesListView()
            }
            .tabItem { Label { Text("Meldinger") } icon: { Self.outlineIcon("bubble.left") } }
            .badge(chatService.unreadCount)
            .tag(3)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label {
                    Text("Profil")
                } icon: {
                    if let img = profileTabImage {
                        Image(uiImage: img)
                    } else {
                        Self.outlineIcon("person.crop.circle")
                    }
                }
            }
            .badge(pendingHostRequests)
            .tag(4)
        }
        .tint(.primary600)
        .environmentObject(chatService)
        .environmentObject(profileStats)
        .ignoresSafeArea(.keyboard)
        .task {
            await loadUnreadCount()
            await loadPendingHostRequests()
            await refreshProfileStats()
            await loadProfileTabImage()
        }
        .onChange(of: authManager.currentUser?.id) { _, _ in
            Task {
                await refreshProfileStats()
                await loadProfileTabImage()
            }
        }
        .onChange(of: authManager.profile?.avatarUrl) { _, _ in
            Task { await loadProfileTabImage() }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab != 3 {
                Task { await loadUnreadCount() }
            }
            if newTab != 4 {
                Task { await loadPendingHostRequests() }
            }
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
}
