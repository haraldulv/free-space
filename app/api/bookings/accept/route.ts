import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { SERVICE_FEE_RATE } from "@/lib/config";
import { sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

const PAYMENT_DEADLINE_HOURS = 24;

/**
 * Godta motpartens siste tilbud. Oppretter PaymentIntent og setter
 * status='awaiting_payment' med 24t-frist.
 *
 * Body: { bookingId, offerId }
 *  - offerId må matche bookings.current_offer_id (optimistic lock).
 *  - Akseptøren kan IKKE være den som la siste tilbud (egne-aksept blokkeres).
 *
 * Returnerer { clientSecret, publishableKey } slik at klienten kan åpne PaymentSheet.
 * Hvis host godtok gjest's tilbud → returnerer status='awaiting_payment_by_guest'
 * og pusher gjest med deep-link til betaling.
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
    const { bookingId, offerId } = body as { bookingId: string; offerId: string };
    if (!bookingId || !offerId) {
      return NextResponse.json({ error: "bookingId og offerId påkrevd" }, { status: 400 });
    }

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, status, current_offer_id, listing_id, listing:listing_id(title)")
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

    if (!["awaiting_host", "awaiting_guest", "requested"].includes(booking.status)) {
      return NextResponse.json({ error: "Forhandlingen er allerede avsluttet" }, { status: 400 });
    }

    if (booking.current_offer_id !== offerId) {
      return NextResponse.json({ error: "Tilbudet er erstattet av et nyere — last inn samtalen på nytt." }, { status: 409 });
    }

    const { data: offer } = await supabase
      .from("booking_offers")
      .select("*")
      .eq("id", offerId)
      .single();
    if (!offer || offer.status !== "pending") {
      return NextResponse.json({ error: "Tilbudet er ikke aktivt" }, { status: 400 });
    }

    // Egen-aksept blokkeres: man kan ikke godta sitt eget tilbud.
    if (offer.proposed_by === user.id) {
      return NextResponse.json({ error: "Du kan ikke godta ditt eget tilbud" }, { status: 400 });
    }

    // Verifiser host's Stripe-konto fortsatt funker.
    const { data: hostProfile } = await supabase
      .from("profiles")
      .select("stripe_account_id, stripe_onboarding_complete")
      .eq("id", booking.host_id!)
      .single();
    if (!hostProfile?.stripe_account_id || !hostProfile?.stripe_onboarding_complete) {
      return NextResponse.json({ error: "Utleier har ikke aktiv Stripe-konto" }, { status: 400 });
    }

    // Opprett PaymentIntent (Connect: separate charges + senere transfer).
    const paymentIntent = await stripe.paymentIntents.create({
      amount: offer.total_price * 100,
      currency: "nok",
      capture_method: "automatic",
      metadata: {
        bookingId: booking.id,
        listingId: booking.listing_id,
        userId: booking.user_id,
        listingTitle: (booking.listing as { title?: string } | null)?.title || "",
        hostStripeAccountId: hostProfile.stripe_account_id,
        serviceFeeRate: String(SERVICE_FEE_RATE),
        offerId: offer.id,
        flow: "negotiation",
      },
    });

    const paymentDeadline = new Date(Date.now() + PAYMENT_DEADLINE_HOURS * 60 * 60 * 1000).toISOString();

    // Oppdater booking — optimistic lock på current_offer_id.
    const { data: updatedBooking, error: updateError } = await supabase
      .from("bookings")
      .update({
        status: "awaiting_payment",
        awaiting_party: null,
        payment_intent_id: paymentIntent.id,
        payment_deadline: paymentDeadline,
        approval_deadline: null,
        check_in: offer.check_in,
        check_out: offer.check_out,
        total_price: offer.total_price,
        selected_extras: offer.selected_extras,
        selected_spot_ids: offer.selected_spot_ids,
        price_breakdown: offer.price_breakdown,
      })
      .eq("id", bookingId)
      .eq("current_offer_id", offerId)
      .select("id")
      .single();

    if (updateError || !updatedBooking) {
      await stripe.paymentIntents.cancel(paymentIntent.id).catch(() => {});
      return NextResponse.json({ error: "Tilbudet ble erstattet underveis. Last inn samtalen på nytt." }, { status: 409 });
    }

    // Marker offer som accepted, og posten i chat.
    await supabase.from("booking_offers").update({ status: "accepted" }).eq("id", offerId);

    const { data: convo } = await supabase
      .from("conversations")
      .select("id")
      .eq("booking_id", bookingId)
      .maybeSingle();

    const acceptorRole = isGuest ? "guest" : "host";
    if (convo?.id) {
      const acceptorName = isGuest ? "Gjest" : "Utleier";
      await supabase.from("messages").insert({
        conversation_id: convo.id,
        sender_id: user.id,
        content: `${acceptorName} godtok tilbudet på ${offer.total_price.toLocaleString("nb-NO")} kr. Venter på betaling innen 24t.`,
        kind: "offer_accepted",
        metadata: {
          offerId,
          bookingId,
          totalPrice: offer.total_price,
          paymentDeadline,
          acceptorRole,
        },
      });
      await supabase.from("conversations")
        .update({ last_message_at: new Date().toISOString() })
        .eq("id", convo.id);
    }

    // Push gjest hvis det var host som godtok (ellers kjører gjest PaymentSheet
    // selv umiddelbart fra acceptResponsen).
    if (isHost) {
      const listingTitle = (booking.listing as { title?: string } | null)?.title || "plassen";
      sendPushToUser(
        booking.user_id,
        "Tilbudet er godtatt!",
        `Utleier godtok ${offer.total_price.toLocaleString("nb-NO")} kr for ${listingTitle}. Fullfør bestillingen innen 24t.`,
        { type: "offer_accepted_pending_payment", bookingId, conversationId: convo?.id || "" },
        { conversationId: convo?.id },
      ).catch((err) => console.warn("[Accept] push failed:", err));
    }

    return NextResponse.json({
      bookingId,
      offerId,
      status: "awaiting_payment",
      paymentDeadline,
      clientSecret: paymentIntent.client_secret,
      publishableKey: process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY,
      // Når gjest var den som klikket Godta, kan klienten åpne PaymentSheet med en gang.
      // Når host klikket, returnerer vi fortsatt client_secret men det er gjest's
      // PaymentSheet som skal trigges via push deep-link.
      acceptorRole,
    });
  } catch (err) {
    console.error("POST /api/bookings/accept error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
