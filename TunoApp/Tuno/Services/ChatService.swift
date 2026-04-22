import Foundation
import Supabase
import Realtime

@MainActor
class ChatService: ObservableObject {
    @Published var conversations: [ConversationPreview] = []
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var unreadCount: Int = 0

    private var realtimeChannel: RealtimeChannelV2?

    // MARK: - Conversations

    /// Henter samtaler i 4 batch-queries istedenfor 1 + 4·N (tidligere waterfall
    /// tok 8–20 sek for 10 samtaler). Nå typisk 300–800 ms uansett antall.
    func loadConversations(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Query 1: alle samtaler brukeren deltar i
            let convos: [Conversation] = try await supabase
                .from("conversations")
                .select()
                .or("guest_id.eq.\(userId),host_id.eq.\(userId)")
                .order("last_message_at", ascending: false)
                .execute()
                .value

            guard !convos.isEmpty else {
                conversations = []
                unreadCount = 0
                return
            }

            let otherUserIds = Array(Set(convos.map { $0.guestId == userId ? $0.hostId : $0.guestId }))
            let listingIds = Array(Set(convos.map { $0.listingId }))
            let convoIds = convos.map { $0.id }

            // Query 2-4: batch-henting parallelt
            async let profilesTask: [Profile] = supabase
                .from("profiles")
                .select()
                .in("id", values: otherUserIds)
                .execute()
                .value
            async let listingsTask: [Listing] = supabase
                .from("listings")
                .select()
                .in("id", values: listingIds)
                .execute()
                .value
            // Hent alle meldinger for samtalene — sortert nyest først så vi kan finne
            // last-message per samtale uten ekstra query. Unread telles også i samme
            // loop. For eksisterende datavolum (Harald + testere) er dette lite — hvis
            // vi senere har tusenvis av meldinger per host, bytt til en view/aggregate.
            async let messagesTask: [Message] = supabase
                .from("messages")
                .select()
                .in("conversation_id", values: convoIds)
                .order("created_at", ascending: false)
                .execute()
                .value
            // Hent alle bookings for de samme listing/guest-parene så vi kan vise
            // status + datoer på conversation-raden.
            async let bookingsTask: [BookingLite] = supabase
                .from("bookings")
                .select("id, listing_id, user_id, status, check_in, check_out, created_at")
                .in("listing_id", values: listingIds)
                .order("created_at", ascending: false)
                .execute()
                .value

            let (profiles, listings, messages, bookings) = try await (profilesTask, listingsTask, messagesTask, bookingsTask)

            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
            let listingMap = Dictionary(uniqueKeysWithValues: listings.map { ($0.id, $0) })

            var lastMessageByConvo: [String: Message] = [:]
            var unreadByConvo: [String: Int] = [:]
            for msg in messages {
                // Først seen per convo = nyest (allerede sortert desc)
                if lastMessageByConvo[msg.conversationId] == nil {
                    lastMessageByConvo[msg.conversationId] = msg
                }
                if !msg.read && msg.senderId != userId {
                    unreadByConvo[msg.conversationId, default: 0] += 1
                }
            }

            // Match seneste booking per (listing_id, guest_id) — sortert desc på created_at
            var latestBookingByPair: [String: BookingLite] = [:]
            for booking in bookings {
                let key = "\(booking.listingId)|\(booking.userId)"
                if latestBookingByPair[key] == nil {
                    latestBookingByPair[key] = booking
                }
            }

            let previews: [ConversationPreview] = convos.map { convo in
                let otherUserId = convo.guestId == userId ? convo.hostId : convo.guestId
                let profile = profileMap[otherUserId]
                let listing = listingMap[convo.listingId]
                let isHost = convo.hostId == userId
                let selfRole = isHost ? "host" : "guest"
                let bookingKey = "\(convo.listingId)|\(convo.guestId)"
                let booking = latestBookingByPair[bookingKey]
                let isArchived = isHost
                    ? (convo.archivedByHost ?? false)
                    : (convo.archivedByGuest ?? false)
                let isStarred = isHost
                    ? (convo.starredByHost ?? false)
                    : (convo.starredByGuest ?? false)
                let isMuted = isHost
                    ? (convo.mutedByHost ?? false)
                    : (convo.mutedByGuest ?? false)
                return ConversationPreview(
                    id: convo.id,
                    listingId: convo.listingId,
                    guestId: convo.guestId,
                    hostId: convo.hostId,
                    otherUserName: profile?.fullName ?? "Anonym",
                    otherUserAvatar: profile?.avatarUrl,
                    lastMessage: lastMessageByConvo[convo.id]?.content ?? "",
                    lastMessageAt: convo.lastMessageAt,
                    unreadCount: unreadByConvo[convo.id] ?? 0,
                    listingTitle: listing?.title ?? "",
                    listingImage: listing?.images?.first,
                    selfRole: selfRole,
                    bookingStatus: booking?.status,
                    bookingDates: booking.flatMap { formatDateRange($0.checkIn, $0.checkOut) },
                    listingCity: listing?.city,
                    isArchived: isArchived,
                    isStarred: isStarred,
                    isMuted: isMuted
                )
            }

            conversations = previews
            // Arkiverte samtaler teller ikke mot tab-badgen — brukeren har signalisert
            // at de ikke vil forholde seg til dem lenger.
            unreadCount = previews.reduce(0) { $1.isArchived ? $0 : $0 + $1.unreadCount }
        } catch {
            print("Failed to load conversations: \(error)")
        }
    }

    // MARK: - Messages

    func loadMessages(conversationId: String) async {
        do {
            let msgs: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: true)
                .execute()
                .value

            messages = msgs.map { msg in
                ChatMessage(
                    id: msg.id,
                    senderId: msg.senderId,
                    content: msg.content,
                    createdAt: msg.createdAt ?? "",
                    read: msg.read
                )
            }
        } catch {
            print("Failed to load messages: \(error)")
        }
    }

    // MARK: - Send message

    func sendMessage(conversationId: String, senderId: String, content: String) async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            try await supabase
                .from("messages")
                .insert([
                    "conversation_id": conversationId,
                    "sender_id": senderId,
                    "content": trimmed
                ])
                .execute()

            // Update conversation timestamp
            try await supabase
                .from("conversations")
                .update(["last_message_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: conversationId)
                .execute()
        } catch {
            self.error = "Kunne ikke sende melding"
            print("Failed to send message: \(error)")
        }
    }

    // MARK: - Get or create conversation

    func getOrCreateConversation(listingId: String, guestId: String, hostId: String) async -> String? {
        do {
            // Check existing
            let existing: [Conversation] = try await supabase
                .from("conversations")
                .select()
                .eq("listing_id", value: listingId)
                .eq("guest_id", value: guestId)
                .execute()
                .value

            if let convo = existing.first {
                return convo.id
            }

            // Create new
            let newConvo: Conversation = try await supabase
                .from("conversations")
                .insert([
                    "listing_id": listingId,
                    "guest_id": guestId,
                    "host_id": hostId
                ])
                .select()
                .single()
                .execute()
                .value

            return newConvo.id
        } catch {
            self.error = "Kunne ikke opprette samtale"
            print("Failed to get/create conversation: \(error)")
            return nil
        }
    }

    // MARK: - Mark as read

    func markAsRead(conversationId: String, userId: String) async {
        do {
            try await supabase
                .from("messages")
                .update(["read": true])
                .eq("conversation_id", value: conversationId)
                .eq("read", value: false)
                .neq("sender_id", value: userId)
                .execute()
        } catch {
            print("Failed to mark as read: \(error)")
        }
    }

    // MARK: - Samtalehandlinger

    /// Marker siste melding fra motparten som ulest, så samtalen dukker opp igjen med unread-indikator.
    func markLatestAsUnread(conversationId: String, currentUserId: String) async {
        do {
            struct MsgId: Decodable { let id: String }
            let latest: [MsgId] = try await supabase
                .from("messages")
                .select("id")
                .eq("conversation_id", value: conversationId)
                .neq("sender_id", value: currentUserId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            guard let target = latest.first else { return }
            try await supabase
                .from("messages")
                .update(["read": false])
                .eq("id", value: target.id)
                .execute()
            // Oppdater lokal state
            if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
                let old = conversations[idx]
                conversations[idx] = replaceUnread(old, with: max(old.unreadCount, 1))
                if !old.isArchived {
                    unreadCount = conversations.reduce(0) { $1.isArchived ? $0 : $0 + $1.unreadCount }
                }
            }
        } catch {
            print("markLatestAsUnread failed: \(error)")
        }
    }

    /// Toggle arkivert-flagg basert på brukerens rolle i samtalen.
    func toggleArchive(conversation: ConversationPreview) async {
        let column = conversation.selfRole == "host" ? "archived_by_host" : "archived_by_guest"
        let newValue = !conversation.isArchived
        await updateConversationFlag(conversationId: conversation.id, column: column, value: newValue) { old in
            ConversationPreview(
                id: old.id, listingId: old.listingId, guestId: old.guestId, hostId: old.hostId,
                otherUserName: old.otherUserName, otherUserAvatar: old.otherUserAvatar,
                lastMessage: old.lastMessage, lastMessageAt: old.lastMessageAt,
                unreadCount: old.unreadCount, listingTitle: old.listingTitle,
                listingImage: old.listingImage, selfRole: old.selfRole,
                bookingStatus: old.bookingStatus, bookingDates: old.bookingDates,
                listingCity: old.listingCity,
                isArchived: newValue, isStarred: old.isStarred, isMuted: old.isMuted
            )
        }
    }

    func toggleStar(conversation: ConversationPreview) async {
        let column = conversation.selfRole == "host" ? "starred_by_host" : "starred_by_guest"
        let newValue = !conversation.isStarred
        await updateConversationFlag(conversationId: conversation.id, column: column, value: newValue) { old in
            ConversationPreview(
                id: old.id, listingId: old.listingId, guestId: old.guestId, hostId: old.hostId,
                otherUserName: old.otherUserName, otherUserAvatar: old.otherUserAvatar,
                lastMessage: old.lastMessage, lastMessageAt: old.lastMessageAt,
                unreadCount: old.unreadCount, listingTitle: old.listingTitle,
                listingImage: old.listingImage, selfRole: old.selfRole,
                bookingStatus: old.bookingStatus, bookingDates: old.bookingDates,
                listingCity: old.listingCity,
                isArchived: old.isArchived, isStarred: newValue, isMuted: old.isMuted
            )
        }
    }

    func toggleMute(conversation: ConversationPreview) async {
        let column = conversation.selfRole == "host" ? "muted_by_host" : "muted_by_guest"
        let newValue = !conversation.isMuted
        await updateConversationFlag(conversationId: conversation.id, column: column, value: newValue) { old in
            ConversationPreview(
                id: old.id, listingId: old.listingId, guestId: old.guestId, hostId: old.hostId,
                otherUserName: old.otherUserName, otherUserAvatar: old.otherUserAvatar,
                lastMessage: old.lastMessage, lastMessageAt: old.lastMessageAt,
                unreadCount: old.unreadCount, listingTitle: old.listingTitle,
                listingImage: old.listingImage, selfRole: old.selfRole,
                bookingStatus: old.bookingStatus, bookingDates: old.bookingDates,
                listingCity: old.listingCity,
                isArchived: old.isArchived, isStarred: old.isStarred, isMuted: newValue
            )
        }
    }

    private func updateConversationFlag(
        conversationId: String,
        column: String,
        value: Bool,
        apply: (ConversationPreview) -> ConversationPreview
    ) async {
        do {
            try await supabase
                .from("conversations")
                .update([column: value])
                .eq("id", value: conversationId)
                .execute()
            if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
                conversations[idx] = apply(conversations[idx])
            }
            unreadCount = conversations.reduce(0) { $1.isArchived ? $0 : $0 + $1.unreadCount }
        } catch {
            print("updateConversationFlag(\(column)) failed: \(error)")
        }
    }

    private func replaceUnread(_ old: ConversationPreview, with count: Int) -> ConversationPreview {
        ConversationPreview(
            id: old.id, listingId: old.listingId, guestId: old.guestId, hostId: old.hostId,
            otherUserName: old.otherUserName, otherUserAvatar: old.otherUserAvatar,
            lastMessage: old.lastMessage, lastMessageAt: old.lastMessageAt,
            unreadCount: count, listingTitle: old.listingTitle,
            listingImage: old.listingImage, selfRole: old.selfRole,
            bookingStatus: old.bookingStatus, bookingDates: old.bookingDates,
            listingCity: old.listingCity,
            isArchived: old.isArchived, isStarred: old.isStarred, isMuted: old.isMuted
        )
    }

    // MARK: - Realtime

    func subscribeToMessages(conversationId: String) async {
        await unsubscribe()

        let channel = supabase.realtimeV2.channel("messages:\(conversationId)")

        let insertions = await channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversationId)"
        )

        await channel.subscribe()
        self.realtimeChannel = channel

        Task {
            for await insertion in insertions {
                guard let decoded = try? insertion.decodeRecord(as: Message.self, decoder: JSONDecoder()) else { continue }
                let msg = ChatMessage(
                    id: decoded.id,
                    senderId: decoded.senderId,
                    content: decoded.content,
                    createdAt: decoded.createdAt ?? "",
                    read: decoded.read
                )
                await MainActor.run {
                    if !self.messages.contains(where: { $0.id == msg.id }) {
                        self.messages.append(msg)
                    }
                }
            }
        }
    }

    func unsubscribe() async {
        if let channel = realtimeChannel {
            await supabase.realtimeV2.removeChannel(channel)
            realtimeChannel = nil
        }
    }
}

// MARK: - View Models

struct ConversationPreview: Identifiable {
    let id: String
    let listingId: String
    let guestId: String
    let hostId: String
    let otherUserName: String
    let otherUserAvatar: String?
    let lastMessage: String
    let lastMessageAt: String?
    let unreadCount: Int
    let listingTitle: String
    let listingImage: String?
    /// Brukerens egen rolle i denne samtalen — "host" hvis utleier, "guest" hvis leietaker.
    let selfRole: String
    /// Status på sist bekreftede/ventende booking ("confirmed"/"requested"/"cancelled"/nil).
    let bookingStatus: String?
    /// Formattert dato-range fra siste booking ("25.-28. feb.") eller nil.
    let bookingDates: String?
    /// By fra listing for secondary-tekst i raden.
    let listingCity: String?
    /// Har gjeldende bruker arkivert denne samtalen (basert på sin rolle).
    let isArchived: Bool
    /// Har gjeldende bruker stjernemerket denne samtalen.
    let isStarred: Bool
    /// Har gjeldende bruker slått av push for denne samtalen.
    let isMuted: Bool
}

struct ChatMessage: Identifiable {
    let id: String
    let senderId: String
    let content: String
    let createdAt: String
    let read: Bool
}

struct BookingLite: Decodable {
    let id: String
    let listingId: String
    let userId: String
    let status: String
    let checkIn: String
    let checkOut: String

    enum CodingKeys: String, CodingKey {
        case id, status
        case listingId = "listing_id"
        case userId = "user_id"
        case checkIn = "check_in"
        case checkOut = "check_out"
    }
}

/// Formatterer en dato-range til kompakt norsk tekst, f.eks. "25.-28. feb." eller
/// "25. feb.-3. mar." hvis det krysser måneder.
private func formatDateRange(_ startStr: String, _ endStr: String) -> String? {
    let parser = DateFormatter()
    parser.dateFormat = "yyyy-MM-dd"
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = TimeZone(identifier: "Europe/Oslo")
    guard let start = parser.date(from: startStr), let end = parser.date(from: endStr) else { return nil }

    let dayOut = DateFormatter()
    dayOut.dateFormat = "d."
    dayOut.locale = Locale(identifier: "nb_NO")
    dayOut.timeZone = TimeZone(identifier: "Europe/Oslo")

    let monthOut = DateFormatter()
    monthOut.dateFormat = "d. MMM."
    monthOut.locale = Locale(identifier: "nb_NO")
    monthOut.timeZone = TimeZone(identifier: "Europe/Oslo")

    let cal = Calendar(identifier: .gregorian)
    let sameMonth = cal.isDate(start, equalTo: end, toGranularity: .month)
    if sameMonth {
        return "\(dayOut.string(from: start))-\(monthOut.string(from: end))"
    } else {
        return "\(monthOut.string(from: start))-\(monthOut.string(from: end))"
    }
}
