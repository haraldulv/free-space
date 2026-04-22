import SwiftUI

enum MessagesFilter: String, CaseIterable {
    case all = "Alle"
    case host = "Som vert"
    case guest = "Som gjest"
    case archived = "Arkivert"
}

struct MessagesListView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var chatService: ChatService
    @State private var showLogin = false
    @State private var filter: MessagesFilter = .all
    @State private var searchActive = false
    @State private var searchText = ""
    @State private var showSettings = false

    private var filtered: [ConversationPreview] {
        var result = chatService.conversations
        switch filter {
        case .all:
            result = result.filter { !$0.isArchived }
        case .host:
            result = result.filter { $0.selfRole == "host" && !$0.isArchived }
        case .guest:
            result = result.filter { $0.selfRole == "guest" && !$0.isArchived }
        case .archived:
            result = result.filter { $0.isArchived }
        }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.otherUserName.lowercased().contains(q)
                    || $0.listingTitle.lowercased().contains(q)
                    || $0.lastMessage.lowercased().contains(q)
            }
        }
        return result
    }

    private var archivedCount: Int {
        chatService.conversations.filter { $0.isArchived }.count
    }

    private var visibleFilters: [MessagesFilter] {
        var options: [MessagesFilter] = [.all, .host, .guest]
        if archivedCount > 0 { options.append(.archived) }
        return options
    }

    var body: some View {
        Group {
            if !authManager.isAuthenticated {
                AuthPromptView(
                    icon: "bubble.left",
                    message: "Logg inn for å se meldingene dine",
                    showLogin: $showLogin
                )
            } else {
                VStack(spacing: 0) {
                    if searchActive {
                        searchBar
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    } else {
                        filterTabs
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }

                    content
                }
            }
        }
        .navigationTitle("Meldinger")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if authManager.isAuthenticated && !searchActive {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { searchActive = true }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.neutral900)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.neutral900)
                    }
                }
            }
        }
        .navigationDestination(for: String.self) { conversationId in
            let convo = chatService.conversations.first(where: { $0.id == conversationId })
            ChatView(
                conversationId: conversationId,
                otherUserName: convo?.otherUserName ?? "",
                listingTitle: convo?.listingTitle ?? "",
                listingId: convo?.listingId,
                listingImage: convo?.listingImage
            )
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showSettings) {
            MessagesSettingsSheet()
        }
        .task {
            guard let userId = authManager.currentUser?.id else { return }
            if chatService.conversations.isEmpty && !chatService.isLoading {
                await chatService.loadConversations(userId: userId.uuidString)
            }
        }
        .refreshable {
            guard let userId = authManager.currentUser?.id else { return }
            await chatService.loadConversations(userId: userId.uuidString)
        }
    }

    // MARK: - Search bar (when active)

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral500)
                TextField("Søk i alle meldinger", text: $searchText)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.neutral100)
            .clipShape(Capsule())

            Button("Avbryt") {
                withAnimation {
                    searchActive = false
                    searchText = ""
                }
                hideKeyboard()
            }
            .font(.system(size: 15))
            .foregroundStyle(.neutral900)
        }
    }

    // MARK: - Filter tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(visibleFilters, id: \.self) { option in
                    Button {
                        withAnimation { filter = option }
                    } label: {
                        Text(option.rawValue)
                            .font(.system(size: 14, weight: filter == option ? .semibold : .medium))
                            .foregroundStyle(filter == option ? .white : .neutral900)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(filter == option ? Color.neutral900 : Color.white)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.neutral200, lineWidth: filter == option ? 0 : 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if chatService.isLoading && chatService.conversations.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filtered.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 40))
                    .foregroundStyle(.neutral300)
                Text(searchText.isEmpty ? "Ingen meldinger" : "Ingen treff på \"\(searchText)\"")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.neutral500)
                if searchText.isEmpty {
                    Text("Meldinger fra utleiere og gjester vises her")
                        .font(.system(size: 14))
                        .foregroundStyle(.neutral400)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { conversation in
                        NavigationLink(value: conversation.id) {
                            AirbnbConversationRow(conversation: conversation)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                Task { await chatService.toggleStar(conversation: conversation) }
                            } label: {
                                Label(conversation.isStarred ? "Fjern stjerne" : "Stjernemerk",
                                      systemImage: conversation.isStarred ? "star.slash" : "star.fill")
                            }
                            Button {
                                Task {
                                    guard let userId = authManager.currentUser?.id else { return }
                                    await chatService.markLatestAsUnread(
                                        conversationId: conversation.id,
                                        currentUserId: userId.uuidString.lowercased()
                                    )
                                }
                            } label: {
                                Label("Merk som ulest", systemImage: "envelope.badge")
                            }
                            Button {
                                Task { await chatService.toggleMute(conversation: conversation) }
                            } label: {
                                Label(conversation.isMuted ? "Slå på varsler" : "Slå av varsler",
                                      systemImage: conversation.isMuted ? "bell" : "bell.slash")
                            }
                            Button(role: .destructive) {
                                Task { await chatService.toggleArchive(conversation: conversation) }
                            } label: {
                                Label(conversation.isArchived ? "Flytt ut av arkiv" : "Arkiver",
                                      systemImage: conversation.isArchived ? "tray.and.arrow.up" : "archivebox")
                            }
                        }
                        Divider().padding(.leading, 82)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Conversation Row

struct AirbnbConversationRow: View {
    let conversation: ConversationPreview

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Listing-thumbnail (48x48 rounded square) med avatar-overlay
            ZStack(alignment: .bottomTrailing) {
                CachedAsyncImage(url: URL(string: conversation.listingImage ?? "")) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.neutral100).overlay(
                        Image(systemName: "photo").foregroundStyle(.neutral300)
                    )
                }
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Avatar i hjørnet
                Group {
                    if let avatarUrl = conversation.otherUserAvatar, let url = URL(string: avatarUrl) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            avatarInitial
                        }
                    } else {
                        avatarInitial
                    }
                }
                .frame(width: 26, height: 26)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .offset(x: 6, y: 6)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(conversation.otherUserName)
                        .font(.system(size: 15, weight: conversation.unreadCount > 0 ? .bold : .semibold))
                        .foregroundStyle(.neutral900)
                        .lineLimit(1)
                    if conversation.isStarred {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#f59e0b"))
                    }
                    if conversation.isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.neutral400)
                    }
                    Spacer()
                    if let dateStr = conversation.lastMessageAt {
                        Text(formatDate(dateStr))
                            .font(.system(size: 12))
                            .foregroundStyle(.neutral400)
                            .layoutPriority(1)
                    }
                }

                Text(conversation.listingTitle)
                    .font(.system(size: 13, weight: conversation.unreadCount > 0 ? .medium : .regular))
                    .foregroundStyle(conversation.unreadCount > 0 ? .neutral900 : .neutral500)
                    .lineLimit(1)

                if !conversation.lastMessage.isEmpty {
                    Text(conversation.lastMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(.neutral500)
                        .lineLimit(1)
                }

                bookingStatusLine
            }

            if conversation.unreadCount > 0 {
                Circle()
                    .fill(Color.primary600)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var bookingStatusLine: some View {
        if let status = conversation.bookingStatus {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor(status))
                    .frame(width: 6, height: 6)
                Text(statusLabel(status))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(statusColor(status))
                if let dates = conversation.bookingDates {
                    Text("·").foregroundStyle(.neutral300)
                    Text(dates)
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                }
                if let city = conversation.listingCity {
                    Text("·").foregroundStyle(.neutral300)
                    Text(city)
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                        .lineLimit(1)
                }
            }
            .padding(.top, 2)
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "confirmed": return Color(hex: "#10b981")
        case "requested", "pending": return Color(hex: "#f59e0b")
        case "cancelled": return .neutral400
        default: return .neutral400
        }
    }

    private func statusLabel(_ status: String) -> String {
        switch status {
        case "confirmed": return "Bekreftet"
        case "requested": return "Venter på svar"
        case "pending": return "Ventende"
        case "cancelled": return "Kansellert"
        default: return status.capitalized
        }
    }

    private var avatarInitial: some View {
        Circle()
            .fill(Color.primary100)
            .overlay(
                Text(String(conversation.otherUserName.prefix(1)).uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary600)
            )
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: iso)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: iso)
        }
        guard let d = date else { return "" }
        let calendar = Calendar.current
        if calendar.isDateInToday(d) {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return df.string(from: d)
        } else if calendar.isDateInYesterday(d) {
            return "I går"
        } else if calendar.isDate(d, equalTo: Date(), toGranularity: .year) {
            let df = DateFormatter()
            df.dateFormat = "d. MMM"
            df.locale = Locale(identifier: "nb_NO")
            return df.string(from: d)
        } else {
            let df = DateFormatter()
            df.dateFormat = "d.M.yy"
            return df.string(from: d)
        }
    }
}

// MARK: - Settings sheet

struct MessagesSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var pushEnabled = true
    @State private var isSaving = false
    @State private var showQuickRepliesEditor = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Varsler") {
                    Toggle("Push-varsler for nye meldinger", isOn: Binding(
                        get: { pushEnabled },
                        set: { newValue in
                            pushEnabled = newValue
                            Task { await savePushEnabled(newValue) }
                        }
                    ))
                    .tint(.primary600)
                    .disabled(isSaving)
                }

                Section("Hurtigsvar") {
                    Button {
                        showQuickRepliesEditor = true
                    } label: {
                        HStack {
                            Image(systemName: "text.bubble")
                                .foregroundStyle(.primary600)
                            Text("Dine hurtigsvar")
                                .foregroundStyle(.neutral900)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundStyle(.neutral400)
                        }
                    }
                }

                Section("Om meldinger") {
                    HStack {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundStyle(.primary600)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hold samtaler i Tuno").font(.system(size: 14, weight: .semibold))
                            Text("Del aldri betalings- eller kontaktinfo utenfor appen — da er du ikke beskyttet.")
                                .font(.system(size: 12))
                                .foregroundStyle(.neutral500)
                        }
                    }
                }
            }
            .navigationTitle("Innstillinger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lukk") { dismiss() }
                }
            }
            .sheet(isPresented: $showQuickRepliesEditor) {
                QuickRepliesEditorSheet()
            }
            .task { await loadPushEnabled() }
        }
    }

    private func loadPushEnabled() async {
        guard let userId = authManager.currentUser?.id else { return }
        do {
            struct Row: Decodable { let pushNotificationsEnabled: Bool?
                enum CodingKeys: String, CodingKey { case pushNotificationsEnabled = "push_notifications_enabled" }
            }
            let rows: [Row] = try await supabase
                .from("profiles")
                .select("push_notifications_enabled")
                .eq("id", value: userId.uuidString.lowercased())
                .limit(1)
                .execute()
                .value
            pushEnabled = rows.first?.pushNotificationsEnabled ?? true
        } catch {
            print("loadPushEnabled: \(error)")
        }
    }

    private func savePushEnabled(_ value: Bool) async {
        guard let userId = authManager.currentUser?.id else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await supabase
                .from("profiles")
                .update(["push_notifications_enabled": value])
                .eq("id", value: userId.uuidString.lowercased())
                .execute()
        } catch {
            print("savePushEnabled: \(error)")
        }
    }
}

// MARK: - Quick reply model + editor

struct QuickReply: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var body: String

    static let defaults: [QuickReply] = [
        QuickReply(id: "welcome", title: "Velkommen", body: "Hei! Takk for bookingen. Velkommen til plassen 👋"),
        QuickReply(id: "checkin", title: "Innsjekk-info", body: "Innsjekk er fra kl. 15. Kjør inn som avtalt — gi beskjed når du er fremme!"),
        QuickReply(id: "checkout", title: "Utsjekk-påminnelse", body: "Hei! Bare en liten påminnelse om at utsjekk er kl. 11. Håper du har hatt det fint!"),
        QuickReply(id: "thanks", title: "Takk for oppholdet", body: "Tusen takk for oppholdet — kom gjerne tilbake! 🚐"),
        QuickReply(id: "contact", title: "Kontaktinfo", body: "Hvis du trenger noe, bare ring eller send en melding her. Jeg svarer så fort jeg kan."),
        QuickReply(id: "confirm", title: "Bekreft", body: "Bekreftet! Ser frem til å ha deg her.")
    ]
}

@MainActor
final class QuickRepliesStore: ObservableObject {
    @Published var replies: [QuickReply] = []
    @Published var isLoading = false

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            struct Row: Decodable {
                let quickReplies: [QuickReply]?
                enum CodingKeys: String, CodingKey { case quickReplies = "quick_replies" }
            }
            let rows: [Row] = try await supabase
                .from("profiles")
                .select("quick_replies")
                .eq("id", value: userId)
                .limit(1)
                .execute()
                .value
            let stored = rows.first?.quickReplies ?? []
            replies = stored.isEmpty ? QuickReply.defaults : stored
        } catch {
            print("QuickReplies load error: \(error)")
            replies = QuickReply.defaults
        }
    }

    func save(userId: String) async {
        do {
            struct Payload: Encodable {
                let quick_replies: [QuickReply]
            }
            try await supabase
                .from("profiles")
                .update(Payload(quick_replies: replies))
                .eq("id", value: userId)
                .execute()
        } catch {
            print("QuickReplies save error: \(error)")
        }
    }
}

struct QuickRepliesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var store = QuickRepliesStore()
    @State private var editing: QuickReply?
    @State private var showAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if store.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(store.replies) { reply in
                                Button {
                                    editing = reply
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(reply.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.neutral900)
                                        Text(reply.body)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.neutral600)
                                            .lineLimit(2)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                store.replies.remove(atOffsets: offsets)
                                Task {
                                    guard let userId = authManager.currentUser?.id else { return }
                                    await store.save(userId: userId.uuidString.lowercased())
                                }
                            }
                            .onMove { from, to in
                                store.replies.move(fromOffsets: from, toOffset: to)
                                Task {
                                    guard let userId = authManager.currentUser?.id else { return }
                                    await store.save(userId: userId.uuidString.lowercased())
                                }
                            }
                        } footer: {
                            Text("Hurtigsvar vises i meldingsfeltet når du trykker +. Tap for å redigere, sveip for å slette.")
                                .font(.system(size: 12))
                                .foregroundStyle(.neutral500)
                        }

                        Section {
                            Button {
                                showAdd = true
                            } label: {
                                Label("Legg til nytt", systemImage: "plus.circle.fill")
                                    .foregroundStyle(.primary600)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hurtigsvar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ferdig") { dismiss() }
                }
            }
            .sheet(item: $editing) { reply in
                QuickReplyEditorView(
                    initial: reply,
                    onSave: { updated in
                        if let idx = store.replies.firstIndex(where: { $0.id == reply.id }) {
                            store.replies[idx] = updated
                        }
                        Task {
                            guard let userId = authManager.currentUser?.id else { return }
                            await store.save(userId: userId.uuidString.lowercased())
                        }
                        editing = nil
                    },
                    onCancel: { editing = nil }
                )
            }
            .sheet(isPresented: $showAdd) {
                QuickReplyEditorView(
                    initial: QuickReply(id: UUID().uuidString, title: "", body: ""),
                    onSave: { new in
                        store.replies.append(new)
                        Task {
                            guard let userId = authManager.currentUser?.id else { return }
                            await store.save(userId: userId.uuidString.lowercased())
                        }
                        showAdd = false
                    },
                    onCancel: { showAdd = false }
                )
            }
            .task {
                guard let userId = authManager.currentUser?.id else { return }
                await store.load(userId: userId.uuidString.lowercased())
            }
        }
    }
}

struct QuickReplyEditorView: View {
    let initial: QuickReply
    let onSave: (QuickReply) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var message: String

    init(initial: QuickReply, onSave: @escaping (QuickReply) -> Void, onCancel: @escaping () -> Void) {
        self.initial = initial
        self.onSave = onSave
        self.onCancel = onCancel
        self._title = State(initialValue: initial.title)
        self._message = State(initialValue: initial.body)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tittel") {
                    TextField("F.eks. Velkommen", text: $title)
                }
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 140)
                } header: {
                    Text("Melding")
                } footer: {
                    Text("Tips: bruk {listing}, {checkin} eller {checkout} for å sette inn navn og tider automatisk.")
                        .font(.system(size: 12))
                }
            }
            .navigationTitle(initial.title.isEmpty ? "Nytt hurtigsvar" : "Rediger")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lagre") {
                        onSave(QuickReply(
                            id: initial.id,
                            title: title.trimmingCharacters(in: .whitespaces),
                            body: message.trimmingCharacters(in: .whitespaces)
                        ))
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || message.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
