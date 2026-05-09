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
 * Godta motpartens siste tilbud — atomisk flyt for gjest, push-flyt for host.
 *
 * Body: { bookingId, offerId }
 *  - offerId må matche bookings.current_offer_id (optimistic lock).
 *
 * Acceptor-rolle bestemmer flyt:
 *
 *  - Gjest godtar host's motbud (atomisk):
 *    Server oppretter PaymentIntent men SKIFTER IKKE status. Booking forblir
 *    `awaiting_guest`. Klient åpner Apple Pay/kort umiddelbart og kaller
 *    payment-confirmed → status=confirmed direkte. Hvis gjest avbryter,
 *    er status uendret og de kan retry — server returnerer da samme
 *    clientSecret idempotent.
 *
 *  - Host godtar gjest's forespørsel:
 *    Server skifter til `awaiting_payment`, oppretter PaymentIntent, marker
 *    offer som accepted, poster chat-melding og pusher gjest. Gjest åpner
 *    appen, ser banner "Fullfør betalingen", trykker → idempotent kall
 *    hit → får eksisterende clientSecret → betaler.
 *
 * Returnerer { bookingId, offerId, status, clientSecret, publishableKey, acceptorRole }.
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
      .select("id, user_id, host_id, status, current_offer_id, listing_id, check_in_time, payment_intent_id, payment_deadline, listing:listing_id(title)")
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

    if (booking.current_offer_id !== offerId) {
      return NextResponse.json({ error: "Tilbudet er erstattet av et nyere — last inn samtalen på nytt." }, { status: 409 });
    }

    const acceptorRole = isGuest ? "guest" : "host";
    const publishableKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY;

    // ── Idempotent path ───────────────────────────────────────────────
    // Hvis booking allerede har en PaymentIntent og PI-en lever, returner
    // samme clientSecret. Dette dekker:
    //  - Gjest avbrøt payment-sheet og prøver igjen
    //  - Host godtok først; gjest tapper banner for å fullføre
    //  - Dobbel-tap pga lag
    if (booking.payment_intent_id) {
      try {
        const pi = await stripe.paymentIntents.retrieve(booking.payment_intent_id);
        if (pi.status === "succeeded") {
          // Betalt allerede — klient skal kalle payment-confirmed for å flushe state.
          return NextResponse.json({
            bookingId,
            offerId,
            status: booking.status,
            alreadyConfirmed: true,
            acceptorRole,
          });
        }
        if (pi.status !== "canceled") {
          return NextResponse.json({
            bookingId,
            offerId,
            status: booking.status,
            paymentDeadline: booking.payment_deadline,
            clientSecret: pi.client_secret,
            publishableKey,
            acceptorRole,
            resumed: true,
          });
        }
        // PI canceled — vi vil opprette ny lenger ned (faller gjennom).
      } catch (err) {
        console.warn("[Accept] retrieve PI failed, creating new:", err);
      }
    }

    // ── First-time path ───────────────────────────────────────────────
    if (!["awaiting_host", "awaiting_guest", "requested"].includes(booking.status)) {
      return NextResponse.json({ error: "Forhandlingen er allerede avsluttet" }, { status: 400 });
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

    // Klipp payment_deadline tidligst på check_in - 1 time.
    const checkInTime = (booking as { check_in_time?: string | null }).check_in_time || "15:00";
    const checkInISO = `${offer.check_in}T${checkInTime}:00+02:00`;
    const checkInMs = new Date(checkInISO).getTime();
    const standardDeadline = Date.now() + PAYMENT_DEADLINE_HOURS * 60 * 60 * 1000;
    const cappedDeadline = !isNaN(checkInMs) ? checkInMs - 60 * 60 * 1000 : standardDeadline;
    const deadlineMs = Math.min(standardDeadline, cappedDeadline);
    const finalDeadlineMs = Math.max(deadlineMs, Date.now() + 30 * 60 * 1000);
    const paymentDeadline = new Date(finalDeadlineMs).toISOString();

    // Branch på acceptor: gjest beholder status (atomisk), host skifter til
    // awaiting_payment som før.
    const updatePayload: Record<string, unknown> = {
      payment_intent_id: paymentIntent.id,
      payment_deadline: paymentDeadline,
      check_in: offer.check_in,
      check_out: offer.check_out,
      total_price: offer.total_price,
      selected_extras: offer.selected_extras,
      selected_spot_ids: offer.selected_spot_ids,
      price_breakdown: offer.price_breakdown,
      approval_deadline: null,
    };

    if (isHost) {
      updatePayload.status = "awaiting_payment";
      updatePayload.awaiting_party = null;
    }
    // For gjest: ingen status-endring. Booking forblir awaiting_guest.

    const { data: updatedBooking, error: updateError } = await supabase
      .from("bookings")
      .update(updatePayload)
      .eq("id", bookingId)
      .eq("current_offer_id", offerId)
      .select("id, status")
      .single();

    if (updateError || !updatedBooking) {
      await stripe.paymentIntents.cancel(paymentIntent.id).catch(() => {});
      return NextResponse.json({ error: "Tilbudet ble erstattet underveis. Last inn samtalen på nytt." }, { status: 409 });
    }

    // Marker offer som accepted KUN ved host-aksept. For gjest's atomic flow
    // skjer det først ved payment-confirmed — slik at hvis gjest avbryter,
    // er offer fortsatt 'pending' og kan re-aksepteres.
    if (isHost) {
      await supabase.from("booking_offers").update({ status: "accepted" }).eq("id", offerId);
    }

    const { data: convo } = await supabase
      .from("conversations")
      .select("id")
      .eq("booking_id", bookingId)
      .maybeSingle();

    // Chat-melding kun ved host-aksept (gjest får "Betaling fullført" via
    // payment-confirmed). Gjestens atomic flow skal ikke produsere flere
    // mellom-meldinger.
    if (isHost && convo?.id) {
      await supabase.from("messages").insert({
        conversation_id: convo.id,
        sender_id: user.id,
        content: `Utleier godtok tilbudet på ${offer.total_price.toLocaleString("nb-NO")} kr. Venter på betaling innen 24t.`,
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

    // Push gjest hvis det var host som godtok.
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
      status: updatedBooking.status,
      paymentDeadline,
      clientSecret: paymentIntent.client_secret,
      publishableKey,
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
