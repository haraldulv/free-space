import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

/**
 * Avslå en pågående forhandling. Begge parter kan avslå.
 *
 * Body: { bookingId, reason? }
 *
 * Markerer bookingen som 'declined' og current_offer som 'declined'. Cancel
 * eventuell PaymentIntent (kun relevant hvis status hadde nådd awaiting_payment).
 */
export async function POST(request: NextRequest) {
  try {
    const authHeader = request.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return NextResponse.json({ error: "Ikke innlogget" }, { status: 401 });
    }
    const token = authHeader.slice(7);
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return NextResponse.json({ error: "Ugyldig token" }, { status: 401 });
    }

    const body = await request.json();
    const { bookingId, reason } = body as { bookingId: string; reason?: string };
    if (!bookingId) {
      return NextResponse.json({ error: "bookingId påkrevd" }, { status: 400 });
    }

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, status, current_offer_id, payment_intent_id, total_price, listing:listing_id(title)")
      .eq("id", bookingId)
      .single();
    if (!booking) {
      return NextResponse.json({ error: "Bestilling ikke funnet" }, { status: 404 });
    }

    const isGuest = booking.user_id === user.id;
    const isHost = booking.host_id === user.id;
    if (!isGuest && !isHost) {
      return NextResponse.json({ error: "Ikke tilgang" }, { status: 403 });
    }

    if (!["awaiting_host", "awaiting_guest", "awaiting_payment", "requested"].includes(booking.status)) {
      return NextResponse.json({ error: "Bestillingen kan ikke avvises i nåværende tilstand" }, { status: 400 });
    }

    // Cancel PaymentIntent hvis den eksisterer.
    if (booking.payment_intent_id) {
      await stripe.paymentIntents.cancel(booking.payment_intent_id).catch((err) => {
        console.warn("paymentIntents.cancel:", err);
      });
    }

    await supabase
      .from("bookings")
      .update({
        status: "declined",
        payment_status: booking.payment_intent_id ? "refunded" : "pending",
        cancelled_at: new Date().toISOString(),
        cancelled_by: isHost ? "host" : "guest",
        cancellation_reason: reason || (isHost ? "host_declined" : "guest_declined"),
        host_responded_at: new Date().toISOString(),
        awaiting_party: null,
        approval_deadline: null,
        payment_deadline: null,
      })
      .eq("id", bookingId);

    if (booking.current_offer_id) {
      await supabase
        .from("booking_offers")
        .update({ status: "declined" })
        .eq("id", booking.current_offer_id);
    }

    const { data: convo } = await supabase
      .from("conversations")
      .select("id")
      .eq("booking_id", bookingId)
      .maybeSingle();

    if (convo?.id) {
      const decliner = isHost ? "Utleier" : "Gjest";
      await supabase.from("messages").insert({
        conversation_id: convo.id,
        sender_id: user.id,
        content: reason
          ? `${decliner} avslo forhandlingen: ${reason}`
          : `${decliner} avslo forhandlingen.`,
        kind: "offer_declined",
        metadata: { bookingId, declinedBy: isHost ? "host" : "guest" },
      });
      await supabase.from("conversations")
        .update({ last_message_at: new Date().toISOString() })
        .eq("id", convo.id);
    }

    // Push motpart.
    const recipientId = isHost ? booking.user_id : booking.host_id;
    const listingTitle = (booking.listing as { title?: string } | null)?.title || "plassen";
    if (recipientId) {
      sendPushToUser(
        recipientId,
        isHost ? "Forespørselen er avvist" : "Gjest avslo tilbudet",
        `${listingTitle} (${booking.total_price.toLocaleString("nb-NO")} kr).`,
        { type: "offer_declined", bookingId, conversationId: convo?.id || "" },
        { conversationId: convo?.id },
      ).catch((err) => console.warn("[Decline] push failed:", err));
    }

    return NextResponse.json({ status: "declined" });
  } catch (err) {
    console.error("POST /api/bookings/decline error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
