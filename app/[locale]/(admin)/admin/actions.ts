"use server";

import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { computeRefund } from "@/lib/cancellation";

function getServiceClient() {
  return createServiceClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );
}

async function requireAdmin() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");

  const { data: profile } = await supabase
    .from("profiles")
    .select("is_admin")
    .eq("id", user.id)
    .single();

  if (!profile?.is_admin) throw new Error("Ikke admin");
  return { supabase: getServiceClient(), user };
}

export async function loadAdminDataAction() {
  const { supabase, user } = await requireAdmin();

  const [bookingRes, profileRes, listingRes, convoRes, supportRes] = await Promise.all([
    supabase
      .from("bookings")
      .select("*, guest:user_id(full_name), host:host_id(full_name), listing:listing_id(title)")
      .order("created_at", { ascending: false })
      .limit(200),
    supabase
      .from("profiles")
      .select("id, full_name, avatar_url, is_admin, created_at, stripe_account_id, stripe_onboarding_complete")
      .order("created_at", { ascending: false }),
    supabase
      .from("listings")
      .select("id, title, city, region, price, category, vehicle_type, is_active, created_at, images, host:host_id(full_name)")
      .order("created_at", { ascending: false }),
    supabase
      .from("conversations")
      .select("id, created_at, last_message_at, type, guest:guest_id(full_name), host:host_id(full_name), listing:listing_id(title)")
      .eq("type", "booking")
      .order("last_message_at", { ascending: false })
      .limit(100),
    supabase
      .from("conversations")
      .select("id, created_at, last_message_at, type, guest_id, guest:guest_id(full_name, avatar_url)")
      .eq("type", "support")
      .order("last_message_at", { ascending: false })
      .limit(200),
  ]);

  // Beregn ulest-tall + siste-melding-preview per support-conversation.
  // En melding er "ulest for admin" når sender = gjesten og read=false (en hvilken
  // som helst admin har ikke svart eller åpnet samtalen ennå).
  const supportRows = (supportRes.data || []) as Array<{ id: string; guest_id: string; [k: string]: unknown }>;
  const supportIds = supportRows.map((c) => c.id);
  let unreadByConvo: Record<string, number> = {};
  let lastMsgByConvo: Record<string, { content: string; created_at: string; sender_id: string }> = {};
  if (supportIds.length > 0) {
    const [unreadRes, lastMsgRes] = await Promise.all([
      // Hent alle uleste gjest-meldinger for support-samtalene
      supabase
        .from("messages")
        .select("conversation_id, sender_id")
        .in("conversation_id", supportIds)
        .eq("read", false),
      supabase
        .from("messages")
        .select("conversation_id, content, created_at, sender_id")
        .in("conversation_id", supportIds)
        .order("created_at", { ascending: false }),
    ]);
    const guestIdByConvo = new Map(supportRows.map((c) => [c.id, c.guest_id]));
    for (const row of unreadRes.data || []) {
      const guestId = guestIdByConvo.get(row.conversation_id as string);
      if (guestId && row.sender_id === guestId) {
        unreadByConvo[row.conversation_id as string] = (unreadByConvo[row.conversation_id as string] ?? 0) + 1;
      }
    }
    for (const row of lastMsgRes.data || []) {
      const cid = row.conversation_id as string;
      if (!lastMsgByConvo[cid]) {
        lastMsgByConvo[cid] = {
          content: row.content as string,
          created_at: row.created_at as string,
          sender_id: row.sender_id as string,
        };
      }
    }
  }
  const supportConversations = supportRows.map((c) => ({
    ...c,
    unread_count: unreadByConvo[c.id] ?? 0,
    last_message: lastMsgByConvo[c.id] ?? null,
  }));

  // Fetch emails from auth.users via admin API
  const { data: authData } = await supabase.auth.admin.listUsers({ perPage: 1000 });
  const emailMap = new Map<string, string>();
  if (authData?.users) {
    for (const u of authData.users) {
      emailMap.set(u.id, u.email || "");
    }
  }

  const users = (profileRes.data || []).map((p: Record<string, unknown>) => ({
    ...p,
    email: emailMap.get(p.id as string) || "",
  }));

  return {
    bookings: bookingRes.data || [],
    users,
    listings: listingRes.data || [],
    conversations: convoRes.data || [],
    supportConversations,
    currentAdminId: user.id,
  };
}

export async function loadSupportMessagesAction(conversationId: string) {
  const { supabase } = await requireAdmin();

  const [messagesRes] = await Promise.all([
    supabase
      .from("messages")
      .select("id, content, created_at, sender_id, sender:sender_id(full_name)")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: true }),
    // Mark gjest-meldinger som read for denne samtalen — én gang admin åpner
    // samtalen er det "sett" på vegne av support-teamet.
    supabase
      .from("messages")
      .update({ read: true })
      .eq("conversation_id", conversationId)
      .eq("read", false),
  ]);

  return messagesRes.data || [];
}

export async function loadSupportUserInfoAction(guestId: string) {
  const { supabase } = await requireAdmin();

  const [profileRes, authUser, bookingsAsGuestRes, bookingsAsHostRes, listingsRes] = await Promise.all([
    supabase
      .from("profiles")
      .select("id, full_name, avatar_url, created_at, stripe_account_id, stripe_onboarding_complete, bio, is_admin")
      .eq("id", guestId)
      .maybeSingle(),
    supabase.auth.admin.getUserById(guestId),
    supabase
      .from("bookings")
      .select("id, status, total_price, check_in, check_out, created_at, listing:listing_id(title)")
      .eq("user_id", guestId)
      .order("created_at", { ascending: false })
      .limit(20),
    supabase
      .from("bookings")
      .select("id, status, total_price, check_in, check_out, created_at, listing:listing_id(title)")
      .eq("host_id", guestId)
      .order("created_at", { ascending: false })
      .limit(20),
    supabase
      .from("listings")
      .select("id, title, city, is_active")
      .eq("host_id", guestId)
      .order("created_at", { ascending: false }),
  ]);

  const guestBookings = bookingsAsGuestRes.data || [];
  const hostBookings = bookingsAsHostRes.data || [];

  return {
    profile: profileRes.data,
    email: authUser.data.user?.email || null,
    emailConfirmed: !!authUser.data.user?.email_confirmed_at,
    createdAt: authUser.data.user?.created_at,
    lastSignInAt: authUser.data.user?.last_sign_in_at,
    provider: authUser.data.user?.app_metadata?.provider || "email",
    bookingsAsGuest: guestBookings,
    bookingsAsHost: hostBookings,
    listings: listingsRes.data || [],
    totalSpent: guestBookings
      .filter((b) => b.status === "confirmed" || b.status === "completed")
      .reduce((sum, b) => sum + (b.total_price || 0), 0),
    totalEarned: hostBookings
      .filter((b) => b.status === "confirmed" || b.status === "completed")
      .reduce((sum, b) => sum + (b.total_price || 0), 0),
  };
}

export async function sendSupportMessageAction(
  conversationId: string,
  content: string,
): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await requireAdmin();

    const trimmed = content.trim();
    if (!trimmed) return { error: "Tom melding" };

    // Verifiser at samtalen faktisk er en support-samtale, ellers åpner vi en
    // tilgang admin ikke skal ha (booking-samtaler er strengt 2-parts).
    const { data: convo } = await supabase
      .from("conversations")
      .select("id, type, guest_id")
      .eq("id", conversationId)
      .single();

    if (!convo || convo.type !== "support") {
      return { error: "Ugyldig samtale" };
    }

    const { error: insertError } = await supabase
      .from("messages")
      .insert({
        conversation_id: conversationId,
        sender_id: user.id,
        content: trimmed,
      });
    if (insertError) return { error: insertError.message };

    await supabase
      .from("conversations")
      .update({
        last_message_at: new Date().toISOString(),
        assigned_admin_id: user.id,
      })
      .eq("id", conversationId);

    // Push til gjest om at support har svart.
    try {
      const { sendPushToUser } = await import("@/lib/push");
      await sendPushToUser(
        convo.guest_id,
        "Tuno-support svarte",
        trimmed.slice(0, 120),
        { conversationId, type: "support_reply" },
        { conversationId },
      );
    } catch (err) {
      console.warn("[Admin] support push failed:", err);
    }

    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function loadMessagesAction(conversationId: string) {
  const { supabase } = await requireAdmin();

  const { data } = await supabase
    .from("messages")
    .select("id, content, created_at, sender:sender_id(full_name)")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: true });

  return data || [];
}

export async function adminDeleteListingAction(listingId: string): Promise<{ error?: string }> {
  try {
    const { supabase } = await requireAdmin();

    const { error } = await supabase
      .from("listings")
      .delete()
      .eq("id", listingId);

    if (error) return { error: error.message };
    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function adminCancelBookingAction(
  bookingId: string,
  reason?: string
): Promise<{ error?: string; refundAmount?: number }> {
  try {
    const { supabase } = await requireAdmin();

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, check_in, total_price, payment_intent_id, payment_status, transfer_status, stripe_transfer_id, status")
      .eq("id", bookingId)
      .single();

    if (!booking) return { error: "Bestilling ikke funnet" };
    if (booking.status === "cancelled") return { error: "Allerede kansellert" };

    const result = computeRefund(booking.total_price, booking.check_in, "host");

    if (booking.transfer_status === "transferred" && booking.stripe_transfer_id) {
      await stripe.transfers.createReversal(booking.stripe_transfer_id);
    }

    if (result.refundAmount > 0 && booking.payment_status === "paid" && booking.payment_intent_id) {
      await stripe.refunds.create({
        payment_intent: booking.payment_intent_id,
        amount: result.refundAmountOre,
      });
    }

    await supabase
      .from("bookings")
      .update({
        status: "cancelled",
        payment_status: result.refundAmount > 0 ? "refunded" : booking.payment_status,
        transfer_status: booking.transfer_status === "transferred" ? "reversed" : "not_applicable",
        cancelled_at: new Date().toISOString(),
        cancelled_by: "host",
        cancellation_reason: reason || "Kansellert av admin",
        refund_amount: result.refundAmount,
      })
      .eq("id", bookingId);

    return { refundAmount: result.refundAmount };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function adminToggleListingAction(
  listingId: string,
  isActive: boolean
): Promise<{ error?: string }> {
  try {
    const { supabase } = await requireAdmin();

    const { error } = await supabase
      .from("listings")
      .update({ is_active: isActive })
      .eq("id", listingId);

    if (error) return { error: error.message };
    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}
