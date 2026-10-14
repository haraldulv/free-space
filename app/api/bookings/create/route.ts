import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { SERVICE_FEE_RATE, MAX_INSTANT_NIGHTS, PARKING_MAX_INSTANT_DAYS } from "@/lib/config";
import { computeBookingTotal } from "@/lib/booking-pricing";
import {
  expandDays,
  normalizeBookedDates,
  firstUnavailableParkingDay,
  peakOccupancy,
  occupiedSpotIds,
  type BookingDayRow,
} from "@/lib/booking-days";
import type { SpotMarker, ListingExtra, SelectedExtras } from "@/types";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(request: NextRequest) {
  try {
    // Authenticate via Bearer token
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
      checkIn: rawCheckIn,
      checkOut: rawCheckOut,
      bookedDates: rawBookedDates,
      licensePlate,
      isRentalCar,
      selectedSpotIds,
      selectedExtras,
    } = body as {
      listingId: string;
      checkIn: string;
      checkOut: string;
      bookedDates?: string[];
      licensePlate?: string;
      isRentalCar?: boolean;
      selectedSpotIds?: string[];
      selectedExtras?: SelectedExtras;
    };

    // Multi-velg (parkering): eksplisitt dagliste. Konvolutten utledes av
    // lista, så klienter kan ikke sende sprikende checkIn/checkOut.
    let bookedDates: string[] | null = null;
    if (rawBookedDates !== undefined) {
      bookedDates = normalizeBookedDates(rawBookedDates);
      if (!bookedDates) {
        return NextResponse.json({ error: "Ugyldig datoliste" }, { status: 400 });
      }
    }
    const checkIn = bookedDates ? bookedDates[0] : rawCheckIn;
    const checkOut = bookedDates ? bookedDates[bookedDates.length - 1] : rawCheckOut;

    if (!listingId || !checkIn || !checkOut) {
      return NextResponse.json({ error: "Mangler påkrevde felt" }, { status: 400 });
    }

    // Check availability
    const { data: listing } = await supabase
      .from("listings")
      .select("spots, host_id, title, price, spot_markers, extras, instant_booking, check_in_time, check_out_time, category, min_stay_days, max_stay_days, moderation_status, host_stripe_ready, is_active, blocked_dates")
      .eq("id", listingId)
      .single();

    if (!listing) {
      return NextResponse.json({ error: "Annonse ikke funnet" }, { status: 404 });
    }
    // Kun godkjente, synlige annonser fra Stripe-verifiserte hosts kan bookes
    // (service-role omgår RLS, så vi sjekker eksplisitt).
    if (listing.moderation_status !== "approved" || !listing.host_stripe_ready || listing.is_active === false) {
      return NextResponse.json({ error: "Annonsen er ikke tilgjengelig for booking" }, { status: 403 });
    }

    if (listing.host_id === user.id) {
      return NextResponse.json({ error: "Du kan ikke booke din egen annonse" }, { status: 400 });
    }

    const isParking = listing.category === "parking";
    if (bookedDates && !isParking) {
      // Camping har eksklusiv utsjekksdag; dagliste-semantikken gjelder kun parkering.
      return NextResponse.json({ error: "Datoliste støttes kun for parkering" }, { status: 400 });
    }

    // Dagene bookingen faktisk opptar. Parkering: inklusiv siste dag (samme
    // konvensjon som prisen). Camping berøres ikke av dag-settene under.
    const requestedDays: string[] = bookedDates ?? expandDays(checkIn, checkOut, true);

    // Min/maks antall dager-validering. Inclusive begge endepunkter (samme
    // konvensjon som pris-utregning): 5. juni → 4. juli = 30 dager.
    const stayDays = bookedDates
      ? bookedDates.length
      : Math.max(
          1,
          Math.round(
            (new Date(checkOut).getTime() - new Date(checkIn).getTime()) / (1000 * 60 * 60 * 24),
          ) + 1,
        );
    if (listing.min_stay_days != null && stayDays < listing.min_stay_days) {
      return NextResponse.json(
        { error: `Denne annonsen krever minimum ${listing.min_stay_days} dager.` },
        { status: 400 },
      );
    }
    if (listing.max_stay_days != null && stayDays > listing.max_stay_days) {
      return NextResponse.json(
        { error: `Denne annonsen tillater maksimum ${listing.max_stay_days} dager.` },
        { status: 400 },
      );
    }

    // Rekalkulér totalen autoritativt server-side — klient sender ikke lenger beløp.
    const { total: totalPrice, breakdown } = await computeBookingTotal({
      listingId,
      listingPrice: listing.price,
      spotMarkers: listing.spot_markers as SpotMarker[] | null,
      listingExtras: listing.extras as ListingExtra[] | null,
      checkIn,
      checkOut,
      bookedDates: bookedDates ?? undefined,
      selectedSpotIds,
      selectedExtras,
    });

    // Stripe krever minst kr 3 for NOK-betalinger.
    if (totalPrice < 3) {
      return NextResponse.json(
        { error: "Bestillingen må være på minst 3 kr." },
        { status: 400 },
      );
    }

    // Konvolutt-prefilter. Parkering: inklusiv grensedag (lte/gte) så en
    // booking som slutter samme dag som vår starter fanges — den dagen er
    // betalt og opptatt (dobbelbooking-bug før 2026-10-12). Camping beholder
    // eksklusiv utsjekksdag (lt/gt).
    let overlapQuery = supabase
      .from("bookings")
      .select("selected_spot_ids, check_in, check_out, booked_dates, status, created_at")
      .eq("listing_id", listingId)
      .in("status", ["confirmed", "pending", "requested"]);
    overlapQuery = isParking
      ? overlapQuery.lte("check_in", checkOut).gte("check_out", checkIn)
      : overlapQuery.lt("check_in", checkOut).gt("check_out", checkIn);
    const { data: rawOverlap } = await overlapQuery;

    // «pending» er en betaling underveis. Forlatte betalinger (lukket app,
    // avbrutt Apple Pay) skal ikke blokkere kalenderen for alltid — de
    // regnes som døde etter 30 minutter.
    const PENDING_TTL_MS = 30 * 60 * 1000;
    const overlappingBookings = (rawOverlap || []).filter(
      (row) =>
        row.status !== "pending" ||
        new Date(row.created_at).getTime() > Date.now() - PENDING_TTL_MS,
    );

    if (isParking) {
      // Per-dag-kapasitet: bare dager vi faktisk ber om teller, så en
      // man-ons-booking stenger ikke tor-fre, og hull i multi-velg forblir
      // ledige for andre. Kapasiteten trekker fra plasser verten manuelt har
      // blokkert den dagen (spot_markers[].blockedDates) — før talte kun
      // bookinger, så vert-blokkering var uten effekt for parkering.
      const fullDay = firstUnavailableParkingDay({
        requestedDays,
        rows: overlappingBookings as BookingDayRow[],
        totalSpots: listing.spots,
        spotMarkers: listing.spot_markers as SpotMarker[] | null,
        listingBlockedDates: listing.blocked_dates as string[] | null,
      });
      if (fullDay) {
        return NextResponse.json({ error: "Ingen ledige plasser for valgte datoer" });
      }
    } else {
      const bookedCount = overlappingBookings.reduce((sum, row) => {
        const ids = row.selected_spot_ids as string[] | null;
        return sum + (ids && ids.length > 0 ? ids.length : 1);
      }, 0);
      if (listing.spots - bookedCount <= 0) {
        return NextResponse.json({ error: "Ingen ledige plasser for valgte datoer" });
      }
    }

    // Sjekk per-spot-konflikt
    if (selectedSpotIds && selectedSpotIds.length > 0) {
      const alreadyBooked = isParking
        ? occupiedSpotIds(overlappingBookings as BookingDayRow[], requestedDays, true)
        : (() => {
            const set = new Set<string>();
            for (const row of overlappingBookings || []) {
              const ids = row.selected_spot_ids as string[] | null;
              (ids || []).forEach((id) => set.add(id));
            }
            return set;
          })();
      const conflict = selectedSpotIds.find((id) => alreadyBooked.has(id));
      if (conflict) {
        return NextResponse.json({ error: "En eller flere av de valgte plassene er allerede booket. Velg andre plasser." });
      }

      // Sjekk manuelt blokkerte datoer per plass. Parkering: alle forespurte
      // dager, inklusiv siste (var eksklusiv — bug). Camping: uendret eksklusiv.
      const spotMarkers = (listing.spot_markers as SpotMarker[] | null) || [];
      const datesInRange: string[] = isParking
        ? requestedDays
        : expandDays(checkIn, checkOut, false);
      for (const spotId of selectedSpotIds) {
        const spot = spotMarkers.find((s) => s.id === spotId);
        if (spot?.blockedDates?.some((d) => datesInRange.includes(d))) {
          return NextResponse.json({ error: `Plass "${spot.label ?? spotId}" er ikke tilgjengelig for valgte datoer.` });
        }
      }
    }

    // Manuelt blokkerte datoer på annonsenivå gjelder ALLE bookinger, også
    // uten plass-valg (EditParkingView pauser via listing.blocked_dates).
    {
      const listingBlocked = (listing.blocked_dates as string[] | null) || [];
      if (listingBlocked.length > 0) {
        const daysToCheck = isParking ? requestedDays : expandDays(checkIn, checkOut, true);
        if (daysToCheck.some((d) => listingBlocked.includes(d))) {
          return NextResponse.json({ error: "Plassen er ikke tilgjengelig for valgte datoer." });
        }
      }
    }

    // Verify host has Stripe Connect
    const { data: hostProfile } = await supabase
      .from("profiles")
      .select("stripe_account_id, stripe_onboarding_complete")
      .eq("id", listing.host_id)
      .single();

    if (!hostProfile?.stripe_account_id || !hostProfile?.stripe_onboarding_complete) {
      return NextResponse.json({ error: "Utleier har ikke satt opp utbetalinger ennå. Prøv igjen senere." });
    }

    // Max-lengde-regelen: lange opphold krever godkjenning uansett.
    // Parkering måles i antall dager (stayDays: inklusiv, eller multi-velg-
    // listens lengde) med grense PARKING_MAX_INSTANT_DAYS så «Fast måneds-
    // plass» (30 dager) går som direktebooking. Camping beholder eksklusive
    // netter mot MAX_INSTANT_NIGHTS.
    const nights = Math.max(
      1,
      Math.round((new Date(checkOut).getTime() - new Date(checkIn).getTime()) / 86400000),
    );
    const exceedsInstantLimit = isParking
      ? stayDays > PARKING_MAX_INSTANT_DAYS
      : nights > MAX_INSTANT_NIGHTS;
    const requiresApproval = listing.instant_booking === false || exceedsInstantLimit;
    const approvalDeadline = requiresApproval
      ? new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
      : null;

    // Insert booking. Parkering skriver alltid booked_dates (også
    // sammenhengende) så alle nedstrøms-lesere har én kilde for dagene.
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .insert({
        user_id: user.id,
        listing_id: listingId,
        check_in: checkIn,
        check_out: checkOut,
        booked_dates: isParking ? requestedDays : null,
        // Snapshot tidspunkter — host-endringer på listing skal ikke ramme eksisterende bookinger.
        check_in_time: (listing.check_in_time as string) || "15:00",
        check_out_time: (listing.check_out_time as string) || "11:00",
        total_price: totalPrice,
        status: "pending",
        payment_status: "pending",
        host_id: listing.host_id,
        license_plate: licensePlate || null,
        is_rental_car: isRentalCar || false,
        approval_deadline: approvalDeadline,
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

    // Post-insert overlap-verifisering (samme logikk som web-server-action).
    let postQuery = supabase
      .from("bookings")
      .select("id, created_at, selected_spot_ids, check_in, check_out, booked_dates")
      .eq("listing_id", listingId)
      .in("status", ["pending", "requested", "confirmed"])
      .order("created_at", { ascending: true });
    postQuery = isParking
      ? postQuery.lte("check_in", checkOut).gte("check_out", checkIn)
      : postQuery.lt("check_in", checkOut).gt("check_out", checkIn);
    const { data: overlapping } = await postQuery;

    if (overlapping) {
      const totalSpots = (listing.spots as number) || 1;
      if (selectedSpotIds && selectedSpotIds.length > 0) {
        const recentRows = overlapping.filter(
          (o) => o.id !== booking.id && new Date(o.created_at).getTime() >= Date.now() - 60000,
        );
        const otherSpots = isParking
          ? occupiedSpotIds(recentRows as BookingDayRow[], requestedDays, true)
          : (() => {
              const set = new Set<string>();
              for (const o of recentRows) {
                for (const sid of (o.selected_spot_ids as string[] | null) || []) {
                  set.add(sid);
                }
              }
              return set;
            })();
        const conflict = selectedSpotIds.find((id: string) => otherSpots.has(id));
        if (conflict) {
          await supabase.from("bookings").delete().eq("id", booking.id);
          return NextResponse.json({ error: "Plassen ble booket av en annen bruker akkurat nå. Velg en annen plass." }, { status: 409 });
        }
      } else if (isParking) {
        // Per-dag: finnes det en forespurt dag der bookinger opprettet FØR
        // vår (created_at-rekkefølgen er stabil taperegel) alt fyller alle
        // plassene, trakk vi det korteste strået i kappløpet.
        const ourIdx = overlapping.findIndex((o) => o.id === booking.id);
        const earlierRows = ourIdx >= 0 ? overlapping.slice(0, ourIdx) : overlapping;
        const peakBeforeUs = peakOccupancy(earlierRows as BookingDayRow[], requestedDays, true);
        if (peakBeforeUs >= totalSpots) {
          await supabase.from("bookings").delete().eq("id", booking.id);
          return NextResponse.json({ error: "Annonsen ble fullbooket av andre brukere akkurat nå. Prøv en annen dato." }, { status: 409 });
        }
      } else if (overlapping.length > totalSpots) {
        const ourIdx = overlapping.findIndex((o) => o.id === booking.id);
        if (ourIdx >= totalSpots) {
          await supabase.from("bookings").delete().eq("id", booking.id);
          return NextResponse.json({ error: "Annonsen ble fullbooket av andre brukere akkurat nå. Prøv en annen dato." }, { status: 409 });
        }
      }
    }

    // Sørg for at det finnes en samtale mellom gjest og host — ingen dead links.
    await supabase
      .from("conversations")
      .upsert(
        {
          listing_id: listingId,
          guest_id: user.id,
          host_id: listing.host_id,
          booking_id: booking.id,
        },
        { onConflict: "listing_id,guest_id", ignoreDuplicates: true },
      );

    // Create Stripe PaymentIntent (amount in øre)
    const paymentIntent = await stripe.paymentIntents.create({
      amount: totalPrice * 100,
      currency: "nok",
      capture_method: requiresApproval ? "manual" : "automatic",
      metadata: {
        bookingId: booking.id,
        listingId,
        userId: user.id,
        listingTitle: listing.title,
        hostStripeAccountId: hostProfile.stripe_account_id,
        serviceFeeRate: String(SERVICE_FEE_RATE),
        requiresApproval: requiresApproval ? "true" : "false",
      },
    });

    // Save payment intent ID
    await supabase
      .from("bookings")
      .update({ payment_intent_id: paymentIntent.id })
      .eq("id", booking.id);

    return NextResponse.json({
      bookingId: booking.id,
      clientSecret: paymentIntent.client_secret,
      publishableKey: process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY,
      requiresApproval,
    });
  } catch (err) {
    console.error("POST /api/bookings/create error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 }
    );
  }
}
