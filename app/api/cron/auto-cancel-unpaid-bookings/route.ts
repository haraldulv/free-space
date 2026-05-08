import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

/**
 * Cron som canceller bookinger der gjest ikke fullførte betaling innen
 * 24t etter at en av partene godtok et tilbud.
 *
 * Kjører hvert 15. min via Vercel Cron.
 */
export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const now = new Date().toISOString();

    const { data: expired } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, payment_intent_id, total_price, current_offer_id, listing:listing_id(title)")
      .eq("status", "awaiting_payment")
      .lt("payment_deadline", now);

    if (!expired || expired.length === 0) {
      return NextResponse.json({ cancelled: 0 });
    }

    let cancelled = 0;
    for (const booking of expired) {
      try {
        if (booking.payment_intent_id) {
          await stripe.paymentIntents.cancel(booking.payment_intent_id).catch((err) => {
            console.warn(`Stripe cancel ${booking.payment_intent_id}:`, err);
          });
        }

        await supabase
          .from("bookings")
          .update({
            status: "expired",
            payment_status: "failed",
            cancelled_at: now,
            cancelled_by: "system",
            cancellation_reason: "payment_deadline_expired",
            payment_deadline: null,
          })
          .eq("id", booking.id);

        if (booking.current_offer_id) {
          await supabase
            .from("booking_offers")
            .update({ status: "expired" })
            .eq("id", booking.current_offer_id);
        }

        const { data: convo } = await supabase
          .from("conversations")
          .select("id")
          .eq("booking_id", booking.id)
          .maybeSingle();

        if (convo?.id) {
          await supabase.from("messages").insert({
            conversation_id: convo.id,
            sender_id: booking.user_id,
            content: "Betalingen ble ikke fullført innen 24 timer. Bestillingen er kansellert.",
            kind: "system",
            metadata: { bookingId: booking.id, reason: "payment_deadline_expired" },
          });
        }

        const listingTitle = (booking.listing as { title?: string } | null)?.title || "plassen";
        const totalStr = booking.total_price.toLocaleString("nb-NO");

        sendPushToUser(
          booking.user_id,
          "Bestillingen utløp",
          `Betalingen for ${listingTitle} (${totalStr} kr) ble ikke fullført innen fristen. Bestillingen er kansellert.`,
          { type: "payment_expired", bookingId: booking.id, conversationId: convo?.id || "" },
          { conversationId: convo?.id },
        ).catch((err) => console.warn("[AutoCancel] push guest failed:", err));

        if (booking.host_id) {
          sendPushToUser(
            booking.host_id,
            "Bestilling utløp",
            `Gjest fullførte ikke betaling for ${listingTitle} innen fristen.`,
            { type: "payment_expired", bookingId: booking.id, conversationId: convo?.id || "" },
            { conversationId: convo?.id },
          ).catch((err) => console.warn("[AutoCancel] push host failed:", err));
        }

        cancelled++;
      } catch (err) {
        console.error(`Auto-cancel ${booking.id}:`, err);
      }
    }

    return NextResponse.json({ cancelled, checked: expired.length });
  } catch (err) {
    console.error("Auto-cancel-unpaid error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
