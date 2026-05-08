"use server";

import { createClient } from "@/lib/supabase/server";
import { sendPushToAllAdmins, sendPushToUser } from "@/lib/push";

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
      .select("id, guest_id, host_id, listing_id, type")
      .eq("id", data.conversationId)
      .single();

    if (!convo) return { error: "Samtale ikke funnet" };

    // Sjekk sender's profil for admin-rolle (kun relevant for support).
    const { data: profile } = await supabase
      .from("profiles")
      .select("full_name, is_admin")
      .eq("id", user.id)
      .single();
    const senderIsAdmin = profile?.is_admin === true;

    const isSupport = convo.type === "support";
    if (!isSupport) {
      if (convo.guest_id !== user.id && convo.host_id !== user.id) {
        return { error: "Ikke tilgang" };
      }
    } else {
      // Support: gjest eller admin kan sende.
      if (convo.guest_id !== user.id && !senderIsAdmin) {
        return { error: "Ikke tilgang" };
      }
    }

    const { error } = await supabase.from("messages").insert({
      conversation_id: data.conversationId,
      sender_id: user.id,
      content: data.content,
    });

    if (error) return { error: error.message };

    const senderName = profile?.full_name || "Noen";
    const preview = data.content.slice(0, 100);

    if (isSupport) {
      if (senderIsAdmin) {
        // Admin svarer → push + notifikasjonsrad til gjest.
        await supabase.from("conversations")
          .update({ assigned_admin_id: user.id })
          .eq("id", data.conversationId);
        await supabase.from("notifications").insert({
          user_id: convo.guest_id,
          type: "new_message",
          title: "Tuno-support svarte",
          body: preview,
          metadata: { conversationId: data.conversationId },
        });
        await sendPushToUser(
          convo.guest_id,
          "Tuno-support svarte",
          preview,
          { type: "new_message", conversationId: data.conversationId },
          { conversationId: data.conversationId },
        );
      } else {
        // Gjest spør → push til alle admins.
        await sendPushToAllAdmins(
          `Support: ${senderName}`,
          preview,
          { type: "support_request", conversationId: data.conversationId },
        );
      }
      return {};
    }

    // Booking-samtale (originaloppførsel)
    const recipientId = convo.guest_id === user.id ? convo.host_id : convo.guest_id;

    const { error: notifError } = await supabase.from("notifications").insert({
      user_id: recipientId,
      type: "new_message",
      title: "Ny melding",
      body: `${senderName}: ${preview}`,
      metadata: { conversationId: data.conversationId },
    });

    if (notifError) {
      console.error("Notification insert error:", notifError.message, "recipientId:", recipientId);
    }

    await sendPushToUser(
      recipientId,
      "Ny melding",
      `${senderName}: ${preview}`,
      { type: "new_message", conversationId: data.conversationId },
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
