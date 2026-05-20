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

            let otherUserIds: [String] = Array(Set(convos.compactMap { convo -> String? in
                // Support-samtaler har ingen "andre bruker" på frontend — vi viser Tuno-support som motpart.
                guard !convo.isSupport else { return nil }
                if convo.guestId == userId {
                    return convo.hostId
                }
                return convo.guestId
            }))
            let listingIds: [String] = Array(Set(convos.compactMap { $0.listingId }))
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
                if convo.isSupport {
                    // Tuno-support har ingen listing/host. Vi bruker "guest"-flaggene for arkiv/star/mute.
                    let isArchived = convo.archivedByGuest ?? false
                    let isStarred = convo.starredByGuest ?? false
                    let isMuted = convo.mutedByGuest ?? false
                    return ConversationPreview(
                        id: convo.id,
                        listingId: nil,
                        guestId: convo.guestId,
                        hostId: nil,
                        otherUserName: "Tuno support",
                        otherUserAvatar: nil,
                        lastMessage: lastMessageByConvo[convo.id]?.content ?? "",
                        lastMessageAt: convo.lastMessageAt,
                        unreadCount: unreadByConvo[convo.id] ?? 0,
                        listingTitle: "Kundeservice",
                        listingImage: nil,
                        selfRole: "guest",
                        bookingStatus: nil,
                        bookingDates: nil,
                        listingCity: nil,
                        isArchived: isArchived,
                        isStarred: isStarred,
                        isMuted: isMuted,
                        kind: "support"
                    )
                }

                let otherUserId = convo.guestId == userId ? (convo.hostId ?? "") : convo.guestId
                let profile = profileMap[otherUserId]
                let listing = convo.listingId.flatMap { listingMap[$0] }
                let isHost = convo.hostId == userId
                let selfRole = isHost ? "host" : "guest"
                let bookingKey = "\(convo.listingId ?? "")|\(convo.guestId)"
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
                    isMuted: isMuted,
                    kind: "booking"
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
                    read: msg.read,
                    kind: msg.kind ?? "text",
                    metadata: msg.metadata
                )
            }
        } catch {
            print("Failed to load messages: \(error)")
        }
    }

    // MARK: - Send message

    func sendMessage(conversationId: String, senderId: String, content: String, isSupport: Bool = false) async {
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

            if isSupport {
                await notifySupport(conversationId: conversationId, content: trimmed)
            }
        } catch {
            self.error = "Kunne ikke sende melding"
            print("Failed to send message: \(error)")
        }
    }

    /// Pinger Tuno-server om at en support-melding er sendt, slik at admins får push.
    /// Direkte Supabase-insert gir ikke push-trigger, så vi gjør et server-call etterpå.
    private func notifySupport(conversationId: String, content: String) async {
        do {
            let session = try await supabase.auth.session
            guard let url = URL(string: "\(AppConfig.siteURL)/api/messages/notify-support") else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            let body: [String: String] = [
                "conversationId": conversationId,
                "content": content,
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            _ = try await URLSession.shared.data(for: req)
        } catch {
            print("notifySupport failed (non-fatal): \(error)")
        }
    }

    // MARK: - Support conversation

    /// Henter eller oppretter brukerens support-samtale med Tuno-support.
    /// type='support', host_id og listing_id er null (DB-skjema tillater det fra 2026-05-08-migrasjonen).
    func getOrCreateSupportConversation(guestId: String) async -> String? {
        do {
            let existing: [Conversation] = try await supabase
                .from("conversations")
                .select()
                .eq("guest_id", value: guestId)
                .eq("type", value: "support")
                .limit(1)
                .execute()
                .value

            if let convo = existing.first {
                return convo.id
            }

            struct SupportInsert: Encodable {
                let guest_id: String
                let type: String
            }
            let newConvo: Conversation = try await supabase
                .from("conversations")
                .insert(SupportInsert(guest_id: guestId, type: "support"))
                .select()
                .single()
                .execute()
                .value

            return newConvo.id
        } catch {
            self.error = "Kunne ikke åpne kundeservice-chat"
            print("getOrCreateSupportConversation: \(error)")
            return nil
        }
    }

    /// Åpner Tuno-support-tråden fra hvor som helst i appen.
    /// Setter pushRouter.pendingConversationId — MainTabView lytter og bytter
    /// til Meldinger-fanen + pusher ChatView automatisk.
    func openOrCreateSupportConversation(userId: UUID, pushRouter: PushRouter) async {
        let guestId = userId.uuidString.lowercased()
        guard let id = await getOrCreateSupportConversation(guestId: guestId) else { return }
        await loadConversations(userId: guestId)
        pushRouter.pendingConversationId = id
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
        // Optimistisk: oppdater lokalt state FØR await, så tab-badge og
        // ulest-prikker krymper umiddelbart når brukeren går inn i chatten.
        // Uten dette ser brukeren 200-500ms av "gammelt" tall mens supabase
        // RTT pågår, som oppleves som en buggy badge.
        if let idx = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[idx] = conversations[idx].with(unreadCount: 0)
            unreadCount = conversations.reduce(0) { $1.isArchived ? $0 : $0 + $1.unreadCount }
        }
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
            // La optimistic state stå — neste loadConversations korrigerer.
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
            old.with(isArchived: newValue)
        }
    }

    func toggleStar(conversation: ConversationPreview) async {
        let column = conversation.selfRole == "host" ? "starred_by_host" : "starred_by_guest"
        let newValue = !conversation.isStarred
        await updateConversationFlag(conversationId: conversation.id, column: column, value: newValue) { old in
            old.with(isStarred: newValue)
        }
    }

    func toggleMute(conversation: ConversationPreview) async {
        let column = conversation.selfRole == "host" ? "muted_by_host" : "muted_by_guest"
        let newValue = !conversation.isMuted
        await updateConversationFlag(conversationId: conversation.id, column: column, value: newValue) { old in
            old.with(isMuted: newValue)
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
        old.with(unreadCount: count)
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
                    read: decoded.read,
                    kind: decoded.kind ?? "text",
                    metadata: decoded.metadata
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
    let listingId: String?
    let guestId: String
    let hostId: String?
    let otherUserName: String
    let otherUserAvatar: String?
    let lastMessage: String
    let lastMessageAt: String?
    let unreadCount: Int
    let listingTitle: String
    let listingImage: String?
    /// Brukerens egen rolle i denne samtalen — "host" hvis utleier, "guest" hvis leietaker, "support" for Tuno-support.
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
    /// "booking" eller "support". Default "booking" for bakoverkompatibilitet.
    let kind: String

    var isSupport: Bool { kind == "support" }

    /// Memberwise-copy som lar oss oppdatere ett felt om gangen uten å re-skrive alle parameterne.
    func with(unreadCount: Int? = nil, isArchived: Bool? = nil, isStarred: Bool? = nil, isMuted: Bool? = nil) -> ConversationPreview {
        ConversationPreview(
            id: id, listingId: listingId, guestId: guestId, hostId: hostId,
            otherUserName: otherUserName, otherUserAvatar: otherUserAvatar,
            lastMessage: lastMessage, lastMessageAt: lastMessageAt,
            unreadCount: unreadCount ?? self.unreadCount,
            listingTitle: listingTitle, listingImage: listingImage, selfRole: selfRole,
            bookingStatus: bookingStatus, bookingDates: bookingDates, listingCity: listingCity,
            isArchived: isArchived ?? self.isArchived,
            isStarred: isStarred ?? self.isStarred,
            isMuted: isMuted ?? self.isMuted,
            kind: kind
        )
    }
}

struct ChatMessage: Identifiable {
    let id: String
    let senderId: String
    let content: String
    let createdAt: String
    let read: Bool
    var kind: String = "text"
    var metadata: OfferMetadata? = nil

    var isOffer: Bool { kind == "offer" }
    var isOfferAccepted: Bool { kind == "offer_accepted" }
    var isOfferDeclined: Bool { kind == "offer_declined" }
    var isSystem: Bool { kind == "system" }
    var isStructured: Bool { kind != "text" }
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
