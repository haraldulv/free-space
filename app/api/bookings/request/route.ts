import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { computeBookingTotal } from "@/lib/booking-pricing";
import { sendPushToUser } from "@/lib/push";
import type { SpotMarker, ListingExtra, SelectedExtras } from "@/types";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

const OFFER_TTL_HOURS = 24;

/**
 * Forespørsel-flyten for instant_booking=false. Ingen Stripe-kall — kun DB.
 * Oppretter:
 *  - bookings (status='awaiting_host', awaiting_party='host')
 *  - booking_offers (proposed_by_role='guest', status='pending')
 *  - conversation hvis den ikke finnes
 *  - chat-melding kind='offer' med offer-id i metadata
 *
 * Push host → "X har sendt en forespørsel".
 *
 * /api/bookings/create beholdes for instant_booking=true (umiddelbar betaling).
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
    const {
      listingId,
      checkIn,
      checkOut,
      licensePlate,
      isRentalCar,
      selectedSpotIds,
      selectedExtras,
      message,
    } = body as {
      listingId: string;
      checkIn: string;
      checkOut: string;
      licensePlate?: string;
      isRentalCar?: boolean;
      selectedSpotIds?: string[];
      selectedExtras?: SelectedExtras;
      message?: string;
    };

    if (!listingId || !checkIn || !checkOut) {
      return NextResponse.json({ error: "Mangler påkrevde felt" }, { status: 400 });
    }

    const { data: listing } = await supabase
      .from("listings")
      .select("spots, host_id, title, price, spot_markers, extras, instant_booking, check_in_time, check_out_time, category, min_stay_days, max_stay_days")
      .eq("id", listingId)
      .single();

    if (!listing) {
      return NextResponse.json({ error: "Annonse ikke funnet" }, { status: 404 });
    }
    if (listing.host_id === user.id) {
      return NextResponse.json({ error: "Du kan ikke booke din egen annonse" }, { status: 400 });
    }

    // Inclusive begge endepunkter (samme konvensjon som pris-utregning):
    // 5. juni → 4. juli = 30 dager, ikke 29.
    const stayDays = Math.max(
      1,
      Math.round(
        (new Date(checkOut).getTime() - new Date(checkIn).getTime()) / (1000 * 60 * 60 * 24),
      ) + 1,
    );
    if (listing.min_stay_days != null && stayDays < listing.min_stay_days) {
      return NextResponse.json({ error: `Denne annonsen krever minimum ${listing.min_stay_days} dager.` }, { status: 400 });
    }
    if (listing.max_stay_days != null && stayDays > listing.max_stay_days) {
      return NextResponse.json({ error: `Denne annonsen tillater maksimum ${listing.max_stay_days} dager.` }, { status: 400 });
    }

    const { total: totalPrice, breakdown } = await computeBookingTotal({
      listingId,
      listingPrice: listing.price,
      spotMarkers: listing.spot_markers as SpotMarker[] | null,
      listingExtras: listing.extras as ListingExtra[] | null,
      checkIn,
      checkOut,
      selectedSpotIds,
      selectedExtras,
    });

    if (totalPrice < 3) {
      return NextResponse.json({ error: "Bestillingen må være på minst 3 kr." }, { status: 400 });
    }

    // Sjekk overlapp: andre forespurte/bekreftede bookinger i samme tidsrom.
    const { data: rawOverlap } = await supabase
      .from("bookings")
      .select("selected_spot_ids, check_in, check_out")
      .eq("listing_id", listingId)
      .in("status", ["confirmed", "pending", "requested", "awaiting_host", "awaiting_guest", "awaiting_payment"])
      .lt("check_in", checkOut)
      .gt("check_out", checkIn);

    const overlappingBookings = rawOverlap || [];
    const bookedCount = overlappingBookings.reduce((sum, row) => {
      const ids = row.selected_spot_ids as string[] | null;
      return sum + (ids && ids.length > 0 ? ids.length : 1);
    }, 0);
    const available = listing.spots - bookedCount;
    if (available <= 0) {
      return NextResponse.json({ error: "Ingen ledige plasser for valgte datoer" });
    }

    if (selectedSpotIds && selectedSpotIds.length > 0) {
      const alreadyBooked = new Set<string>();
      for (const row of overlappingBookings) {
        const ids = row.selected_spot_ids as string[] | null;
        (ids || []).forEach((id) => alreadyBooked.add(id));
      }
      const conflict = selectedSpotIds.find((id) => alreadyBooked.has(id));
      if (conflict) {
        return NextResponse.json({ error: "En eller flere av de valgte plassene er allerede booket. Velg andre plasser." });
      }
    }

    // Verifiser host har Stripe Connect (sjekkes igjen ved /accept, men hindrer
    // unyttige forespørsler her).
    const { data: hostProfile } = await supabase
      .from("profiles")
      .select("stripe_account_id, stripe_onboarding_complete")
      .eq("id", listing.host_id)
      .single();

    if (!hostProfile?.stripe_account_id || !hostProfile?.stripe_onboarding_complete) {
      return NextResponse.json({ error: "Utleier har ikke satt opp utbetalinger ennå. Prøv igjen senere." });
    }

    // Opprett booking-rad uten Stripe.
    const expiresAt = new Date(Date.now() + OFFER_TTL_HOURS * 60 * 60 * 1000).toISOString();
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .insert({
        user_id: user.id,
        listing_id: listingId,
        check_in: checkIn,
        check_out: checkOut,
        check_in_time: (listing.check_in_time as string) || "15:00",
        check_out_time: (listing.check_out_time as string) || "11:00",
        total_price: totalPrice,
        status: "awaiting_host",
        payment_status: "pending",
        host_id: listing.host_id,
        license_plate: licensePlate || null,
        is_rental_car: isRentalCar || false,
        approval_deadline: expiresAt,
        awaiting_party: "host",
        negotiation_round: 1,
        selected_spot_ids: selectedSpotIds && selectedSpotIds.length > 0 ? selectedSpotIds : null,
        selected_extras: selectedExtras && (selectedExtras.listing?.length || Object.keys(selectedExtras.spots || {}).length)
          ? selectedExtras
          : null,
        price_breakdown: breakdown,
      })
      .select("id")
      .single();

    if (bookingError) {
      return NextResponse.json({ error: bookingError.message }, { status: 500 });
    }

    // Første tilbud i forhandlingen.
    const { data: offer, error: offerError } = await supabase
      .from("booking_offers")
      .insert({
        booking_id: booking.id,
        proposed_by: user.id,
        proposed_by_role: "guest",
        total_price: totalPrice,
        price_breakdown: breakdown,
        check_in: checkIn,
        check_out: checkOut,
        selected_extras: selectedExtras ?? null,
        selected_spot_ids: selectedSpotIds ?? null,
        message: message ?? null,
        status: "pending",
        expires_at: expiresAt,
      })
      .select("id")
      .single();

    if (offerError) {
      // Rull tilbake bookingen hvis offer feiler — ellers ligger den der dead.
      await supabase.from("bookings").delete().eq("id", booking.id);
      return NextResponse.json({ error: offerError.message }, { status: 500 });
    }

    await supabase.from("bookings").update({ current_offer_id: offer.id }).eq("id", booking.id);

    // Conversation + chat-melding kind='offer'.
    const { data: convo } = await supabase
      .from("conversations")
      .upsert(
        {
          listing_id: listingId,
          guest_id: user.id,
          host_id: listing.host_id,
          booking_id: booking.id,
          type: "booking",
        },
        { onConflict: "listing_id,guest_id" },
      )
      .select("id")
      .single();

    if (convo?.id) {
      await supabase.from("messages").insert({
        conversation_id: convo.id,
        sender_id: user.id,
        content: message?.trim() || `Forespørsel om ${totalPrice.toLocaleString("nb-NO")} kr`,
        kind: "offer",
        metadata: {
          offerId: offer.id,
          bookingId: booking.id,
          totalPrice,
          checkIn,
          checkOut,
          proposedByRole: "guest",
          round: 1,
          expiresAt,
        },
      });
    }

    // Push host.
    const { data: guestProfile } = await supabase
      .from("profiles")
      .select("full_name")
      .eq("id", user.id)
      .single();
    const guestName = guestProfile?.full_name || "En gjest";
    sendPushToUser(
      listing.host_id,
      "Ny forespørsel",
      `${guestName} har sendt forespørsel om ${totalPrice.toLocaleString("nb-NO")} kr for ${listing.title}.`,
      { type: "offer_received", bookingId: booking.id, conversationId: convo?.id || "" },
      { conversationId: convo?.id },
    ).catch((err) => console.warn("[Request] push failed:", err));

    return NextResponse.json({
      bookingId: booking.id,
      offerId: offer.id,
      conversationId: convo?.id ?? null,
      totalPrice,
    });
  } catch (err) {
    console.error("POST /api/bookings/request error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
