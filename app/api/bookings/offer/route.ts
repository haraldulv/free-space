import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

const OFFER_TTL_HOURS = 24;

/**
 * Motbud i en pågående forhandling.
 *
 * Sjekker at parten som sender motbud er den som har "ballen" (awaiting_party).
 * Bruker optimistic lock på current_offer_id for å håndtere race condition
 * (begge parter kunne klikke "Send motbud" samtidig fra forskjellige offer-bobler).
 *
 * Body: { bookingId, totalPrice, checkIn?, checkOut?, message? }
 *  - checkIn/checkOut er valgfrie. Hvis ikke gitt, beholdes datoer fra forrige tilbud.
 *  - totalPrice er påkrevd og må være innenfor sanity-range (10–1000% av baseline).
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
    const { bookingId, totalPrice, checkIn, checkOut, message } = body as {
      bookingId: string;
      totalPrice: number;
      checkIn?: string;
      checkOut?: string;
      message?: string;
    };

    if (!bookingId || !totalPrice || totalPrice < 3) {
      return NextResponse.json({ error: "bookingId og totalPrice (>=3 kr) påkrevd" }, { status: 400 });
    }

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, status, current_offer_id, negotiation_round, listing_id, total_price")
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

    // Bare den som har "ballen" kan sende motbud.
    if (!["awaiting_host", "awaiting_guest", "requested"].includes(booking.status)) {
      return NextResponse.json({ error: "Forhandlingen er avsluttet" }, { status: 400 });
    }
    const expectedSender = booking.status === "awaiting_host" || booking.status === "requested" ? "host" : "guest";
    if ((expectedSender === "host" && !isHost) || (expectedSender === "guest" && !isGuest)) {
      return NextResponse.json({ error: "Det er motpartens tur å svare" }, { status: 400 });
    }

    // Sanity-range basert på listing-baseline.
    const { data: listing } = await supabase
      .from("listings")
      .select("price, title, instant_booking, check_in_time, check_out_time")
      .eq("id", booking.listing_id)
      .single();
    if (!listing) {
      return NextResponse.json({ error: "Annonse ikke funnet" }, { status: 404 });
    }

    if (totalPrice < 3) {
      return NextResponse.json({ error: "Pris må være minst 3 kr" }, { status: 400 });
    }
    // Maks 10x baseline-totalen som forrige tilbud — beskytter mot tullete tall.
    if (totalPrice > booking.total_price * 10 && totalPrice > listing.price * 100) {
      return NextResponse.json({ error: "Prisen er urealistisk høy" }, { status: 400 });
    }

    // Hent forrige aktive tilbud for å arve datoer hvis ikke endret.
    const { data: prevOffer } = await supabase
      .from("booking_offers")
      .select("*")
      .eq("id", booking.current_offer_id!)
      .single();
    if (!prevOffer) {
      return NextResponse.json({ error: "Forrige tilbud ikke funnet" }, { status: 500 });
    }

    const newCheckIn = checkIn ?? prevOffer.check_in;
    const newCheckOut = checkOut ?? prevOffer.check_out;
    const newRound = booking.negotiation_round + 1;
    const newAwaitingParty = expectedSender === "host" ? "guest" : "host";
    const newStatus = newAwaitingParty === "host" ? "awaiting_host" : "awaiting_guest";
    const expiresAt = new Date(Date.now() + OFFER_TTL_HOURS * 60 * 60 * 1000).toISOString();

    // Marker forrige tilbud som superseded.
    await supabase
      .from("booking_offers")
      .update({ status: "superseded" })
      .eq("id", prevOffer.id);

    // Opprett nytt tilbud.
    const { data: newOffer, error: insertError } = await supabase
      .from("booking_offers")
      .insert({
        booking_id: bookingId,
        proposed_by: user.id,
        proposed_by_role: expectedSender,
        total_price: totalPrice,
        price_breakdown: prevOffer.price_breakdown,
        check_in: newCheckIn,
        check_out: newCheckOut,
        selected_extras: prevOffer.selected_extras,
        selected_spot_ids: prevOffer.selected_spot_ids,
        message: message ?? null,
        status: "pending",
        expires_at: expiresAt,
      })
      .select("id")
      .single();
    if (insertError) {
      return NextResponse.json({ error: insertError.message }, { status: 500 });
    }

    // Optimistic lock: oppdater bare hvis current_offer_id fortsatt matcher det vi leste.
    const { data: updatedBooking, error: updateError } = await supabase
      .from("bookings")
      .update({
        current_offer_id: newOffer.id,
        negotiation_round: newRound,
        awaiting_party: newAwaitingParty,
        status: newStatus,
        approval_deadline: expiresAt,
        check_in: newCheckIn,
        check_out: newCheckOut,
        total_price: totalPrice,
      })
      .eq("id", bookingId)
      .eq("current_offer_id", prevOffer.id)
      .select("id")
      .single();

    if (updateError || !updatedBooking) {
      // Race: annen part rakk å sende motbud først. Roll tilbake nytt tilbud.
      await supabase.from("booking_offers").delete().eq("id", newOffer.id);
      await supabase.from("booking_offers").update({ status: "pending" }).eq("id", prevOffer.id);
      return NextResponse.json({ error: "Den andre parten sendte et tilbud akkurat nå. Last inn samtalen på nytt." }, { status: 409 });
    }

    // Hent conversation for å poste offer-melding.
    const { data: convo } = await supabase
      .from("conversations")
      .select("id")
      .eq("booking_id", bookingId)
      .maybeSingle();

    if (convo?.id) {
      await supabase.from("messages").insert({
        conversation_id: convo.id,
        sender_id: user.id,
        content: message?.trim() || `Motbud: ${totalPrice.toLocaleString("nb-NO")} kr`,
        kind: "offer",
        metadata: {
          offerId: newOffer.id,
          bookingId,
          totalPrice,
          checkIn: newCheckIn,
          checkOut: newCheckOut,
          proposedByRole: expectedSender,
          round: newRound,
          expiresAt,
        },
      });
      await supabase.from("conversations")
        .update({ last_message_at: new Date().toISOString() })
        .eq("id", convo.id);
    }

    // Push motpart.
    const recipientId = newAwaitingParty === "host" ? booking.host_id : booking.user_id;
    const { data: senderProfile } = await supabase
      .from("profiles")
      .select("full_name")
      .eq("id", user.id)
      .single();
    const senderName = senderProfile?.full_name || (expectedSender === "host" ? "Utleier" : "Gjest");
    sendPushToUser(
      recipientId!,
      "Nytt prisforslag",
      `${senderName} foreslår ${totalPrice.toLocaleString("nb-NO")} kr for ${listing.title}.`,
      { type: "offer_received", bookingId, conversationId: convo?.id || "" },
      { conversationId: convo?.id },
    ).catch((err) => console.warn("[Offer] push failed:", err));

    return NextResponse.json({
      offerId: newOffer.id,
      round: newRound,
      awaitingParty: newAwaitingParty,
      expiresAt,
    });
  } catch (err) {
    console.error("POST /api/bookings/offer error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
