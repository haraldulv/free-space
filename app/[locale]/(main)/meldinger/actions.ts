"use server";

import { createClient } from "@/lib/supabase/server";
import { sendPushToUser } from "@/lib/push";

async function getAuthUser() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");
  return { supabase, user };
}

export async function getOrCreateConversationAction(data: {
  listingId: string;
  hostId: string;
}): Promise<{ conversationId?: string; error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    if (user.id === data.hostId) {
      return { error: "Du kan ikke sende melding til deg selv" };
    }

    // Check for existing conversation
    const { data: existing } = await supabase
      .from("conversations")
      .select("id")
      .eq("listing_id", data.listingId)
      .eq("guest_id", user.id)
      .maybeSingle();

    if (existing) {
      return { conversationId: existing.id };
    }

    // Create new conversation
    const { data: convo, error } = await supabase
      .from("conversations")
      .insert({
        listing_id: data.listingId,
        guest_id: user.id,
        host_id: data.hostId,
      })
      .select("id")
      .single();

    if (error) return { error: error.message };
    return { conversationId: convo.id };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function sendMessageAction(data: {
  conversationId: string;
  content: string;
}): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    // Verify user is participant
    const { data: convo } = await supabase
      .from("conversations")
      .select("id, guest_id, host_id, listing_id")
      .eq("id", data.conversationId)
      .single();

    if (!convo) return { error: "Samtale ikke funnet" };
    if (convo.guest_id !== user.id && convo.host_id !== user.id) {
      return { error: "Ikke tilgang" };
    }

    const { error } = await supabase.from("messages").insert({
      conversation_id: data.conversationId,
      sender_id: user.id,
      content: data.content,
    });

    if (error) return { error: error.message };

    // Notify the other user
    const recipientId = convo.guest_id === user.id ? convo.host_id : convo.guest_id;

    // Get sender name
    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name")
      .eq("id", user.id)
      .single();

    const { error: notifError } = await supabase.from("notifications").insert({
      user_id: recipientId,
      type: "new_message",
      title: "Ny melding",
      body: `${profile?.full_name || "Noen"}: ${data.content.slice(0, 100)}`,
      metadata: { conversationId: data.conversationId },
    });

    if (notifError) {
      console.error("Notification insert error:", notifError.message, "recipientId:", recipientId);
    }

    // Send push notification to recipient's device
    const senderName = profile?.full_name || "Noen";
    await sendPushToUser(
      recipientId,
      "Ny melding",
      `${senderName}: ${data.content.slice(0, 100)}`,
    );

    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function markMessagesReadAction(conversationId: string): Promise<void> {
  const { supabase, user } = await getAuthUser();

  await supabase
    .from("messages")
    .update({ read: true })
    .eq("conversation_id", conversationId)
    .neq("sender_id", user.id)
    .eq("read", false);
}
