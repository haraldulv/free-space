import { createClient } from "./client";
import type { Conversation, Message } from "@/types";

export async function getConversations(userId: string): Promise<Conversation[]> {
  const supabase = createClient();

  const { data, error } = await supabase
    .from("conversations")
    .select(`
      *,
      guest:guest_id(full_name, avatar_url),
      host:host_id(full_name, avatar_url),
      listing:listing_id(title, images)
    `)
    .or(`guest_id.eq.${userId},host_id.eq.${userId}`)
    .order("last_message_at", { ascending: false });

  if (error || !data) return [];

  // Get last message and unread count for each conversation
  const conversations: Conversation[] = [];
  for (const row of data) {
    const isGuest = row.guest_id === userId;
    const otherUser = isGuest
      ? (row.host as Record<string, unknown>)
      : (row.guest as Record<string, unknown>);
    const listing = row.listing as Record<string, unknown> | null;

    // Get last message
    const { data: lastMsg } = await supabase
      .from("messages")
      .select("content")
      .eq("conversation_id", row.id)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();

    // Get unread count
    const { count } = await supabase
      .from("messages")
      .select("id", { count: "exact", head: true })
      .eq("conversation_id", row.id)
      .eq("read", false)
      .neq("sender_id", userId);

    conversations.push({
      id: row.id,
      listingId: row.listing_id,
      guestId: row.guest_id,
      hostId: row.host_id,
      bookingId: row.booking_id,
      lastMessageAt: row.last_message_at,
      createdAt: row.created_at,
      otherUserName: (otherUser?.full_name as string) || "Anonym",
      otherUserAvatar: (otherUser?.avatar_url as string) || "",
      listingTitle: (listing?.title as string) || "",
      listingImage: ((listing?.images as string[]) || [])[0] || "",
      lastMessageText: lastMsg?.content || "",
      unreadCount: count || 0,
    });
  }

  return conversations;
}

export async function getMessages(conversationId: string): Promise<Message[]> {
  const supabase = createClient();

  const { data, error } = await supabase
    .from("messages")
    .select("*, sender:sender_id(full_name, avatar_url)")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: true });

  if (error || !data) return [];

  return data.map((row) => {
    const sender = row.sender as Record<string, unknown> | null;
    return {
      id: row.id,
      conversationId: row.conversation_id,
      senderId: row.sender_id,
      content: row.content,
      read: row.read,
      createdAt: row.created_at,
      senderName: (sender?.full_name as string) || "Anonym",
      senderAvatar: (sender?.avatar_url as string) || "",
    };
  });
}

export async function getUnreadMessageCount(userId: string): Promise<number> {
  const supabase = createClient();

  // Get all conversation IDs for this user
  const { data: convos } = await supabase
    .from("conversations")
    .select("id")
    .or(`guest_id.eq.${userId},host_id.eq.${userId}`);

  if (!convos || convos.length === 0) return 0;

  const { count } = await supabase
    .from("messages")
    .select("id", { count: "exact", head: true })
    .in("conversation_id", convos.map((c) => c.id))
    .eq("read", false)
    .neq("sender_id", userId);

  return count || 0;
}

export function subscribeToMessages(
  conversationId: string,
  onMessage: (message: Message) => void,
) {
  const supabase = createClient();

  return supabase
    .channel(`messages:${conversationId}`)
    .on(
      "postgres_changes",
      {
        event: "INSERT",
        schema: "public",
        table: "messages",
        filter: `conversation_id=eq.${conversationId}`,
      },
      async (payload) => {
        const row = payload.new as Record<string, unknown>;
        // Fetch sender info
        const { data: sender } = await supabase
          .from("profiles")
          .select("full_name, avatar_url")
          .eq("id", row.sender_id as string)
          .single();

        onMessage({
          id: row.id as string,
          conversationId: row.conversation_id as string,
          senderId: row.sender_id as string,
          content: row.content as string,
          read: row.read as boolean,
          createdAt: row.created_at as string,
          senderName: sender?.full_name || "Anonym",
          senderAvatar: sender?.avatar_url || "",
        });
      },
    )
    .subscribe();
}
