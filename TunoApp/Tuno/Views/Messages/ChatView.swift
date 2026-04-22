import SwiftUI

struct ChatView: View {
    let conversationId: String
    let otherUserName: String
    let listingTitle: String
    var listingId: String? = nil
    var listingImage: String? = nil

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var globalChat: ChatService
    @StateObject private var chatService = ChatService()
    @State private var messageText = ""
    @State private var showListingDetail = false
    @State private var showOpplysninger = false
    @State private var showQuickReplies = false
    @State private var showHostProfile = false
    @State private var conversationDetails: ConversationDetails?
    @State private var actionToast: String?
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private var currentPreview: ConversationPreview? {
        globalChat.conversations.first(where: { $0.id == conversationId })
    }

    private var currentUserId: String {
        authManager.currentUser?.id.uuidString.lowercased() ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            chatHeader

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(chatService.messages.enumerated()), id: \.element.id) { index, message in
                            let isMe = message.senderId == currentUserId
                            let prev = index > 0 ? chatService.messages[index - 1] : nil
                            let showHeader = prev == nil
                                || prev!.senderId != message.senderId
                                || timeGap(from: prev!.createdAt, to: message.createdAt) > 600

                            if showHeader, !isMe {
                                MessageHeader(
                                    name: otherUserName,
                                    isHost: conversationDetails?.isHost(senderId: message.senderId) ?? false,
                                    timestamp: formatHeaderTime(message.createdAt)
                                )
                                .padding(.top, index == 0 ? 4 : 10)
                                .padding(.leading, 44)
                            }

                            MessageBubble(
                                message: message,
                                isMe: isMe,
                                avatarUrl: isMe ? nil : conversationDetails?.otherAvatar,
                                otherUserInitial: String(otherUserName.prefix(1))
                            )
                            .id(message.id)
                        }

                        if let typicalResponseTime = conversationDetails?.typicalResponseTime {
                            HStack(spacing: 6) {
                                Image(systemName: "clock")
                                    .font(.system(size: 11))
                                Text("Typisk svartid: \(typicalResponseTime)")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(.neutral500)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .onChange(of: chatService.messages.count) {
                    if let last = chatService.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let last = chatService.messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            // Input
            VStack(spacing: 0) {
                Divider()
                HStack(alignment: .bottom, spacing: 10) {
                    Button {
                        showQuickReplies = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.neutral700)
                            .frame(width: 36, height: 36)
                            .background(Color.neutral100)
                            .clipShape(Circle())
                    }

                    TextField("Skriv en melding...", text: $messageText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...5)
                        .focused($isInputFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.neutral50)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.neutral200, lineWidth: 1)
                        )

                    Button {
                        Task { await sendMessage() }
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.neutral300 : Color.neutral900
                            )
                            .clipShape(Circle())
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.white)
            }
        }
        .overlay(alignment: .top) {
            if let toast = actionToast {
                Text(toast)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.neutral900)
                    .clipShape(Capsule())
                    .padding(.top, 70)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .shadow(color: .black.opacity(0.2), radius: 6)
            }
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showListingDetail) {
            if let listingId {
                ListingDetailView(listingId: listingId)
            }
        }
        .sheet(isPresented: $showOpplysninger) {
            OpplysningerSheet(
                details: conversationDetails,
                preview: currentPreview,
                listingImage: listingImage,
                listingTitle: listingTitle,
                listingId: listingId,
                onShowListing: {
                    showOpplysninger = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showListingDetail = true
                    }
                },
                onShowHostProfile: {
                    showOpplysninger = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showHostProfile = true
                    }
                },
                onMarkUnread: {
                    guard let convo = currentPreview else { return }
                    Task {
                        await globalChat.markLatestAsUnread(conversationId: convo.id, currentUserId: currentUserId)
                        showOpplysninger = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            dismiss()
                        }
                    }
                },
                onToggleStar: {
                    guard let convo = currentPreview else { return }
                    Task {
                        await globalChat.toggleStar(conversation: convo)
                        flashToast(convo.isStarred ? "Fjernet stjerne" : "Stjernemerket")
                    }
                },
                onToggleArchive: {
                    guard let convo = currentPreview else { return }
                    Task {
                        await globalChat.toggleArchive(conversation: convo)
                        showOpplysninger = false
                        if !convo.isArchived {
                            // Brukeren arkiverte nå — gå tilbake til listen
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                dismiss()
                            }
                        }
                    }
                },
                onToggleMute: {
                    guard let convo = currentPreview else { return }
                    Task {
                        await globalChat.toggleMute(conversation: convo)
                        flashToast(convo.isMuted ? "Varsler slått på" : "Varsler slått av")
                    }
                }
            )
        }
        .sheet(isPresented: $showQuickReplies) {
            QuickRepliesSheet(
                listing: conversationDetails?.listing,
                onSelect: { reply in
                    messageText = messageText.isEmpty ? reply : "\(messageText) \(reply)"
                    showQuickReplies = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isInputFocused = true
                    }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHostProfile) {
            if let hostId = conversationDetails?.hostId {
                PublicProfileView(
                    hostId: hostId,
                    initialName: conversationDetails?.hostName,
                    initialAvatar: conversationDetails?.hostAvatar,
                    initialJoinedYear: conversationDetails?.hostJoinedYear,
                    initialListingsCount: nil
                )
            }
        }
        .task {
            await chatService.loadMessages(conversationId: conversationId)
            await chatService.subscribeToMessages(conversationId: conversationId)
            await chatService.markAsRead(conversationId: conversationId, userId: currentUserId)
            await loadConversationDetails()
        }
        .onDisappear {
            Task { await chatService.unsubscribe() }
        }
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .frame(width: 36, height: 36)
            }

            VStack(spacing: 2) {
                // Avatar stack (kun én avatar i Tuno — 1-on-1)
                HStack(spacing: 0) {
                    if let avatar = conversationDetails?.otherAvatar, let url = URL(string: avatar) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { avatarPlaceholder }
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    } else {
                        avatarPlaceholder
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    }
                }

                Text(otherUserName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.neutral900)

                if let details = conversationDetails, let dates = details.bookingDates {
                    Text("\(dates) · \(listingTitle)")
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)
                        .lineLimit(1)
                } else if !listingTitle.isEmpty {
                    Text(listingTitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.neutral500)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                showOpplysninger = true
            } label: {
                Text("Opplysninger")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.neutral900)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(
                        Capsule().stroke(Color.neutral300, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.primary100)
            .overlay(
                Text(String(otherUserName.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary600)
            )
    }

    // MARK: - Helpers

    private func flashToast(_ text: String) {
        withAnimation { actionToast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { actionToast = nil }
        }
    }

    private func sendMessage() async {
        let text = messageText
        messageText = ""
        await chatService.sendMessage(
            conversationId: conversationId,
            senderId: currentUserId,
            content: text
        )
    }

    private func loadConversationDetails() async {
        guard let listingId else { return }
        do {
            let convo: [ConversationRow] = try await supabase
                .from("conversations")
                .select("id, listing_id, guest_id, host_id")
                .eq("id", value: conversationId)
                .limit(1)
                .execute()
                .value
            guard let c = convo.first else { return }

            let otherUserId = c.hostId == currentUserId ? c.guestId : c.hostId

            async let profileTask: [Profile] = supabase
                .from("profiles")
                .select()
                .eq("id", value: otherUserId)
                .limit(1)
                .execute()
                .value

            async let listingTask: [Listing] = supabase
                .from("listings")
                .select()
                .eq("id", value: listingId)
                .limit(1)
                .execute()
                .value

            async let bookingsTask: [BookingLite] = supabase
                .from("bookings")
                .select("id, listing_id, user_id, status, check_in, check_out, created_at")
                .eq("listing_id", value: listingId)
                .eq("user_id", value: c.guestId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            let (profiles, listings, bookings) = try await (profileTask, listingTask, bookingsTask)
            let profile = profiles.first
            let listing = listings.first
            let booking = bookings.first

            conversationDetails = ConversationDetails(
                hostId: c.hostId,
                guestId: c.guestId,
                otherAvatar: profile?.avatarUrl,
                hostName: c.hostId == currentUserId ? authManager.profile?.fullName : profile?.fullName,
                hostAvatar: c.hostId == currentUserId ? authManager.profile?.avatarUrl : profile?.avatarUrl,
                hostJoinedYear: listing?.hostJoinedYear,
                listing: listing,
                bookingId: booking?.id,
                bookingStatus: booking?.status,
                bookingDates: booking.map { formatBookingRange($0.checkIn, $0.checkOut) },
                typicalResponseTime: "noen timer"
            )
        } catch {
            print("loadConversationDetails error: \(error)")
        }
    }

    private func timeGap(from a: String, to b: String) -> TimeInterval {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let da = f.date(from: a) ?? { f.formatOptions = [.withInternetDateTime]; return f.date(from: a) }()
        let db = f.date(from: b) ?? { f.formatOptions = [.withInternetDateTime]; return f.date(from: b) }()
        guard let da, let db else { return 0 }
        return db.timeIntervalSince(da)
    }

    private func formatHeaderTime(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: iso)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: iso)
        }
        guard let d = date else { return "" }
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df.string(from: d)
    }

    private func formatBookingRange(_ startStr: String, _ endStr: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "Europe/Oslo")
        guard let start = parser.date(from: startStr), let end = parser.date(from: endStr) else {
            return "\(startStr) – \(endStr)"
        }
        let dayOut = DateFormatter()
        dayOut.dateFormat = "d."
        dayOut.locale = Locale(identifier: "nb_NO")
        dayOut.timeZone = TimeZone(identifier: "Europe/Oslo")
        let monthOut = DateFormatter()
        monthOut.dateFormat = "d. MMM."
        monthOut.locale = Locale(identifier: "nb_NO")
        monthOut.timeZone = TimeZone(identifier: "Europe/Oslo")
        let cal = Calendar(identifier: .gregorian)
        if cal.isDate(start, equalTo: end, toGranularity: .month) {
            return "\(dayOut.string(from: start))–\(monthOut.string(from: end))"
        } else {
            return "\(monthOut.string(from: start))–\(monthOut.string(from: end))"
        }
    }
}

// MARK: - Message header (name · time)

struct MessageHeader: View {
    let name: String
    let isHost: Bool
    let timestamp: String

    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.neutral700)
            if isHost {
                Text("· Vert")
                    .font(.system(size: 12))
                    .foregroundStyle(.neutral500)
            }
            Text(timestamp)
                .font(.system(size: 12))
                .foregroundStyle(.neutral400)
                .padding(.leading, 4)
        }
    }
}

// MARK: - Message bubble (med avatar på mottakers-side)

struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool
    var avatarUrl: String? = nil
    var otherUserInitial: String = "?"

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isMe {
                Group {
                    if let avatarUrl, let url = URL(string: avatarUrl) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { avatarInitial }
                    } else {
                        avatarInitial
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
            }

            if isMe { Spacer(minLength: 40) }

            Text(message.content)
                .font(.system(size: 15))
                .foregroundStyle(isMe ? .white : .neutral900)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isMe ? Color.neutral900 : Color.neutral100)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            if !isMe { Spacer(minLength: 40) }
        }
    }

    private var avatarInitial: some View {
        Circle()
            .fill(Color.primary100)
            .overlay(
                Text(otherUserInitial.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary600)
            )
    }
}

// MARK: - Conversation details

struct ConversationDetails {
    let hostId: String
    let guestId: String
    let otherAvatar: String?
    let hostName: String?
    let hostAvatar: String?
    let hostJoinedYear: Int?
    let listing: Listing?
    let bookingId: String?
    let bookingStatus: String?
    let bookingDates: String?
    let typicalResponseTime: String?

    func isHost(senderId: String) -> Bool {
        senderId.lowercased() == hostId.lowercased()
    }
}

private struct ConversationRow: Decodable {
    let id: String
    let listingId: String
    let guestId: String
    let hostId: String

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case guestId = "guest_id"
        case hostId = "host_id"
    }
}

// MARK: - Opplysninger-sheet

struct OpplysningerSheet: View {
    let details: ConversationDetails?
    let preview: ConversationPreview?
    let listingImage: String?
    let listingTitle: String
    let listingId: String?
    let onShowListing: () -> Void
    let onShowHostProfile: () -> Void
    let onMarkUnread: () -> Void
    let onToggleStar: () -> Void
    let onToggleArchive: () -> Void
    let onToggleMute: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Turen
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Opplysninger om turen")
                            .font(.system(size: 18, weight: .bold))

                        Button(action: onShowListing) {
                            HStack(spacing: 12) {
                                CachedAsyncImage(url: URL(string: listingImage ?? "")) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(Color.neutral100)
                                }
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(details?.listing?.city ?? listingTitle)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.neutral900)
                                    if let dates = details?.bookingDates, let status = details?.bookingStatus {
                                        Text("\(statusLabel(status)) · \(dates)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.neutral500)
                                    } else if details?.bookingStatus != nil {
                                        Text(statusLabel(details?.bookingStatus ?? "") )
                                            .font(.system(size: 12))
                                            .foregroundStyle(.neutral500)
                                    }
                                    Text(listingTitle)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.neutral400)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.neutral400)
                            }
                            .padding(12)
                            .background(Color.neutral50)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    // Deltakere
                    if let details {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("I denne samtalen")
                                .font(.system(size: 18, weight: .bold))

                            Button(action: onShowHostProfile) {
                                HStack(spacing: 12) {
                                    Group {
                                        if let url = URL(string: details.hostAvatar ?? "") {
                                            CachedAsyncImage(url: url) { image in
                                                image.resizable().aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Circle().fill(Color.primary100)
                                            }
                                        } else {
                                            Circle().fill(Color.primary100)
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(details.hostName ?? "Utleier")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.neutral900)
                                        Text("Vert")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.neutral500)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.neutral400)
                                }
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Samtalehandlinger
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Samtalehandlinger")
                            .font(.system(size: 18, weight: .bold))
                            .padding(.bottom, 8)

                        actionRow(icon: "envelope.open", label: "Merk som ulest") { onMarkUnread() }
                        Divider()
                        actionRow(
                            icon: (preview?.isStarred ?? false) ? "star.fill" : "star",
                            label: (preview?.isStarred ?? false) ? "Fjern stjerne" : "Stjernemerk"
                        ) { onToggleStar() }
                        Divider()
                        actionRow(
                            icon: (preview?.isArchived ?? false) ? "tray.and.arrow.up" : "archivebox",
                            label: (preview?.isArchived ?? false) ? "Flytt ut av arkiv" : "Arkiver"
                        ) { onToggleArchive() }
                        Divider()
                        actionRow(
                            icon: (preview?.isMuted ?? false) ? "bell" : "bell.slash",
                            label: (preview?.isMuted ?? false) ? "Slå på varsler igjen" : "Slå av varsler for denne samtalen"
                        ) { onToggleMute() }
                    }
                }
                .padding(20)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.neutral900)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func actionRow(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.neutral700)
                    .frame(width: 24)
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(.neutral900)
                Spacer()
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
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
}

// MARK: - Quick replies sheet

struct QuickRepliesSheet: View {
    let listing: Listing?
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var store = QuickRepliesStore()
    @State private var showEditor = false

    /// Substituerer {listing}, {checkin}, {checkout} med faktiske verdier fra booking-listingen.
    /// Slik trenger host bare skrive én mal og få aktuell tid/navn inn automatisk.
    private func expand(_ body: String) -> String {
        body
            .replacingOccurrences(of: "{listing}", with: listing?.title ?? "plassen")
            .replacingOccurrences(of: "{checkin}", with: listing?.checkInTime ?? "15:00")
            .replacingOccurrences(of: "{checkout}", with: listing?.checkOutTime ?? "11:00")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Trykk på et hurtigsvar for å sette det inn i meldingsfeltet. Bruk {listing}, {checkin} og {checkout} i egne svar for å sette inn aktuell info automatisk.")
                        .font(.system(size: 12))
                        .foregroundStyle(.neutral500)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    if store.isLoading {
                        ProgressView().padding(.top, 20)
                    } else {
                        ForEach(store.replies) { reply in
                            Button {
                                onSelect(expand(reply.body))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reply.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.neutral900)
                                    Text(expand(reply.body))
                                        .font(.system(size: 13))
                                        .foregroundStyle(.neutral600)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .background(Color.neutral50)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal, 20)
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Hurtigsvar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showEditor = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lukk") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditor, onDismiss: {
                // Reload etter redigering så listen speiler eventuelle endringer
                Task {
                    guard let userId = authManager.currentUser?.id else { return }
                    await store.load(userId: userId.uuidString.lowercased())
                }
            }) {
                QuickRepliesEditorSheet()
            }
            .task {
                guard let userId = authManager.currentUser?.id else { return }
                await store.load(userId: userId.uuidString.lowercased())
            }
        }
    }
}
