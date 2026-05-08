import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

/**
 * Idempotent overgang awaiting_payment → confirmed etter at gjest fullførte
 * PaymentSheet på klienten. Stripe webhook (payment_intent.succeeded) kaller
 * den samme overgangen for redundans hvis klienten dropper kall (f.eks.
 * mister nett etter betaling).
 *
 * Body: { bookingId }
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
    const { bookingId } = body as { bookingId: string };
    if (!bookingId) {
      return NextResponse.json({ error: "bookingId påkrevd" }, { status: 400 });
    }

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, status, payment_intent_id, total_price, listing:listing_id(title)")
      .eq("id", bookingId)
      .single();
    if (!booking) {
      return NextResponse.json({ error: "Bestilling ikke funnet" }, { status: 404 });
    }
    if (booking.user_id !== user.id) {
      return NextResponse.json({ error: "Ikke tilgang" }, { status: 403 });
    }

    // Idempotent — hvis allerede confirmed, retur OK uten endring.
    if (booking.status === "confirmed") {
      return NextResponse.json({ status: "confirmed", alreadyProcessed: true });
    }
    if (booking.status !== "awaiting_payment") {
      return NextResponse.json({ error: "Bestillingen er ikke klar for betaling" }, { status: 400 });
    }
    if (!booking.payment_intent_id) {
      return NextResponse.json({ error: "Mangler PaymentIntent" }, { status: 500 });
    }

    // Verifiser hos Stripe at PaymentIntent faktisk lyktes.
    const pi = await stripe.paymentIntents.retrieve(booking.payment_intent_id);
    if (pi.status !== "succeeded") {
      return NextResponse.json({ error: `Betaling ikke fullført (status: ${pi.status})` }, { status: 400 });
    }

    await supabase
      .from("bookings")
      .update({
        status: "confirmed",
        payment_status: "paid",
        host_responded_at: new Date().toISOString(),
        payment_deadline: null,
      })
      .eq("id", bookingId);

    // Post system-melding i chat.
    const { data: convo } = await supabase
      .from("conversations")
      .select("id")
      .eq("booking_id", bookingId)
      .maybeSingle();
    if (convo?.id) {
      await supabase.from("messages").insert({
        conversation_id: convo.id,
        sender_id: user.id,
        content: `Betaling fullført. Bestillingen er bekreftet.`,
        kind: "system",
        metadata: { bookingId },
      });
    }

    // Push host.
    const listingTitle = (booking.listing as { title?: string } | null)?.title || "plassen";
    sendPushToUser(
      booking.host_id!,
      "Booking bekreftet",
      `Gjest har betalt ${booking.total_price.toLocaleString("nb-NO")} kr for ${listingTitle}.`,
      { type: "booking_confirmed", bookingId, conversationId: convo?.id || "" },
      { conversationId: convo?.id },
    ).catch((err) => console.warn("[PaymentConfirmed] push failed:", err));

    return NextResponse.json({ status: "confirmed" });
  } catch (err) {
    console.error("POST /api/bookings/payment-confirmed error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
