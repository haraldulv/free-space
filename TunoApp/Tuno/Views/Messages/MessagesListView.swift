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
                    topBar

                    if !searchActive {
                        filterTabs
                            .padding(.top, 8)
                            .padding(.bottom, 4)
                    }

                    content
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
        .navigationBarHidden(true)
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

    // MARK: - Top bar

    @ViewBuilder
    private var topBar: some View {
        if searchActive {
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
            .padding(.horizontal, 16)
            .padding(.top, 8)
        } else {
            HStack {
                Text("Meldinger")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                Button {
                    withAnimation { searchActive = true }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.neutral900)
                        .frame(width: 36, height: 36)
                        .background(Color.neutral100)
                        .clipShape(Circle())
                }
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 17))
                        .foregroundStyle(.neutral900)
                        .frame(width: 36, height: 36)
                        .background(Color.neutral100)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
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
    @AppStorage("tuno.messages.pushEnabled") private var pushEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Varsler") {
                    Toggle("Push-varsler for nye meldinger", isOn: $pushEnabled)
                        .tint(.primary600)
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
        }
    }
}
