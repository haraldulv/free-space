import SwiftUI

/// Aggregert varsel-oversikt — leser fra public.notifications-tabellen.
/// Tap på et varsel navigerer til relevant skjerm basert på type + metadata.
struct NotificationsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var store = NotificationsStore()
    @Environment(\.dismiss) private var dismiss
    @State private var navigateTo: NotificationTarget?
    @State private var showClearConfirm = false

    var body: some View {
        Group {
            if store.isLoading && store.notifications.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if store.notifications.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Varsler")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !store.notifications.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showClearConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.neutral700)
                    }
                }
            }
        }
        .alert("Tøm varsler?", isPresented: $showClearConfirm) {
            Button("Tøm alle", role: .destructive) {
                Task {
                    guard let userId = authManager.currentUser?.id else { return }
                    await store.deleteAll(userId: userId.uuidString.lowercased())
                }
            }
            Button("Avbryt", role: .cancel) {}
        } message: {
            Text("Alle varsler vil slettes permanent.")
        }
        .task {
            guard let userId = authManager.currentUser?.id else { return }
            await store.load(userId: userId.uuidString.lowercased())
            await store.markAllRead(userId: userId.uuidString.lowercased())
        }
        .refreshable {
            guard let userId = authManager.currentUser?.id else { return }
            await store.load(userId: userId.uuidString.lowercased())
        }
        .navigationDestination(item: $navigateTo) { target in
            switch target {
            case .conversation(let id):
                ChatView(
                    conversationId: id,
                    otherUserName: "",
                    listingTitle: "",
                    listingId: nil,
                    listingImage: nil
                )
            case .hostRequests:
                HostRequestsView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell")
                .font(.system(size: 36))
                .foregroundStyle(.neutral300)
            Text("Ingen varslinger ennå")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.neutral900)
            Text("Du har blanke ark (enn så lenge). Vi gir deg beskjed når det kommer oppdateringer.")
                .font(.system(size: 14))
                .foregroundStyle(.neutral500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.notifications) { notif in
                    NotificationRow(notification: notif)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleTap(notif)
                        }
                    Divider().padding(.leading, 62)
                }
            }
        }
    }

    private func handleTap(_ notif: AppNotification) {
        if let convoId = notif.metadata?["conversationId"] {
            navigateTo = .conversation(id: convoId)
        } else if notif.type == "booking_received" {
            navigateTo = .hostRequests
        }
    }
}

enum NotificationTarget: Hashable {
    case conversation(id: String)
    case hostRequests
}

// MARK: - Row

private struct NotificationRow: View {
    let notification: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(notification.title)
                    .font(.system(size: 14, weight: notification.read ? .semibold : .bold))
                    .foregroundStyle(.neutral900)
                if let body = notification.body, !body.isEmpty {
                    Text(body)
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral600)
                        .lineLimit(3)
                }
                Text(relativeTime)
                    .font(.system(size: 11))
                    .foregroundStyle(.neutral400)
                    .padding(.top, 2)
            }

            Spacer()

            if !notification.read {
                Circle().fill(Color.primary600).frame(width: 8, height: 8).padding(.top, 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var iconName: String {
        switch notification.type {
        case "booking_received": return "tray.and.arrow.down.fill"
        case "booking_confirmed": return "checkmark.seal.fill"
        case "booking_cancelled": return "xmark.circle.fill"
        case "new_message": return "bubble.left.fill"
        case "new_review": return "star.fill"
        case "payout_sent": return "dollarsign.circle.fill"
        default: return "bell.fill"
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case "booking_received", "booking_confirmed", "payout_sent": return Color.primary600
        case "booking_cancelled": return .red
        case "new_message": return Color(hex: "#3b82f6")
        case "new_review": return Color(hex: "#f59e0b")
        default: return .neutral600
        }
    }

    private var iconBackground: Color {
        iconColor.opacity(0.12)
    }

    private var relativeTime: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = f.date(from: notification.createdAt ?? "")
        if date == nil {
            f.formatOptions = [.withInternetDateTime]
            date = f.date(from: notification.createdAt ?? "")
        }
        guard let d = date else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.locale = Locale(identifier: "nb_NO")
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: d, relativeTo: Date())
    }
}

// MARK: - Model + store

struct AppNotification: Identifiable, Decodable, Hashable {
    let id: String
    let userId: String
    let type: String
    let title: String
    let body: String?
    let read: Bool
    let createdAt: String?
    /// metadata-jsonb fra DB. Vi bruker kun string-verdier i praksis
    /// (conversationId, bookingId), så dekoder som [String: String].
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, read
        case userId = "user_id"
        case createdAt = "created_at"
        case metadata
    }
}

@MainActor
final class NotificationsStore: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var isLoading = false
    @Published var unreadCount: Int = 0

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [AppNotification] = try await supabase
                .from("notifications")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()
                .value
            notifications = rows
            unreadCount = rows.filter { !$0.read }.count
        } catch {
            print("NotificationsStore load error: \(error)")
        }
    }

    func loadUnreadCount(userId: String) async {
        do {
            let count = try await supabase
                .from("notifications")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userId)
                .eq("read", value: false)
                .execute()
                .count ?? 0
            unreadCount = count
        } catch {
            print("NotificationsStore loadUnreadCount error: \(error)")
        }
    }

    func markAllRead(userId: String) async {
        do {
            try await supabase
                .from("notifications")
                .update(["read": true])
                .eq("user_id", value: userId)
                .eq("read", value: false)
                .execute()
            notifications = notifications.map { n in
                AppNotification(
                    id: n.id, userId: n.userId, type: n.type, title: n.title,
                    body: n.body, read: true, createdAt: n.createdAt, metadata: n.metadata
                )
            }
            unreadCount = 0
        } catch {
            print("NotificationsStore markAllRead error: \(error)")
        }
    }

    /// Slett alle varsler for denne brukeren permanent.
    func deleteAll(userId: String) async {
        do {
            try await supabase
                .from("notifications")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            notifications = []
            unreadCount = 0
        } catch {
            print("NotificationsStore deleteAll error: \(error)")
        }
    }
}
