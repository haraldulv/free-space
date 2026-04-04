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

    func loadConversations(userId: String) async {
        isLoading = true
        do {
            let convos: [Conversation] = try await supabase
                .from("conversations")
                .select()
                .or("guest_id.eq.\(userId),host_id.eq.\(userId)")
                .order("last_message_at", ascending: false)
                .execute()
                .value

            var previews: [ConversationPreview] = []

            for convo in convos {
                let isGuest = convo.guestId == userId
                let otherUserId = isGuest ? convo.hostId : convo.guestId

                // Fetch other user's profile
                let profile: Profile? = try? await supabase
                    .from("profiles")
                    .select()
                    .eq("id", value: otherUserId)
                    .single()
                    .execute()
                    .value

                // Fetch listing title + image
                let listing: Listing? = try? await supabase
                    .from("listings")
                    .select()
                    .eq("id", value: convo.listingId)
                    .single()
                    .execute()
                    .value

                // Get last message
                let lastMessages: [Message] = try await supabase
                    .from("messages")
                    .select()
                    .eq("conversation_id", value: convo.id)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value

                // Count unread
                let allMessages: [Message] = try await supabase
                    .from("messages")
                    .select()
                    .eq("conversation_id", value: convo.id)
                    .eq("read", value: false)
                    .neq("sender_id", value: userId)
                    .execute()
                    .value

                previews.append(ConversationPreview(
                    id: convo.id,
                    listingId: convo.listingId,
                    guestId: convo.guestId,
                    hostId: convo.hostId,
                    otherUserName: profile?.fullName ?? "Anonym",
                    otherUserAvatar: profile?.avatarUrl,
                    lastMessage: lastMessages.first?.content ?? "",
                    lastMessageAt: convo.lastMessageAt,
                    unreadCount: allMessages.count,
                    listingTitle: listing?.title ?? "",
                    listingImage: listing?.images?.first
                ))
            }

            conversations = previews
            unreadCount = previews.reduce(0) { $0 + $1.unreadCount }
        } catch {
            print("Failed to load conversations: \(error)")
        }
        isLoading = false
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
            // Fetch unread messages not sent by current user, then update them
            let unread: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId)
                .eq("read", value: false)
                .neq("sender_id", value: userId)
                .execute()
                .value

            for msg in unread {
                try await supabase
                    .from("messages")
                    .update(["read": true])
                    .eq("id", value: msg.id)
                    .execute()
            }
        } catch {
            print("Failed to mark as read: \(error)")
        }
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
}

struct ChatMessage: Identifiable {
    let id: String
    let senderId: String
    let content: String
    let createdAt: String
    let read: Bool
}
