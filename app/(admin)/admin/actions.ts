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
  const { supabase } = await requireAdmin();

  const [bookingRes, userRes, listingRes, convoRes] = await Promise.all([
    supabase
      .from("bookings")
      .select("*, guest:user_id(full_name), host:host_id(full_name), listing:listing_id(title)")
      .order("created_at", { ascending: false })
      .limit(200),
    supabase
      .from("profiles")
      .select("id, full_name, email, avatar_url, is_admin, created_at, stripe_account_id, stripe_onboarding_complete")
      .order("created_at", { ascending: false }),
    supabase
      .from("listings")
      .select("id, title, city, region, price, category, vehicle_type, is_active, created_at, images, host:host_id(full_name)")
      .order("created_at", { ascending: false }),
    supabase
      .from("conversations")
      .select("id, created_at, last_message_at, guest:guest_id(full_name), host:host_id(full_name), listing:listing_id(title)")
      .order("last_message_at", { ascending: false })
      .limit(100),
  ]);

  return {
    bookings: bookingRes.data || [],
    users: userRes.data || [],
    listings: listingRes.data || [],
    conversations: convoRes.data || [],
  };
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
