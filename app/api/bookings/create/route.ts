import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { SERVICE_FEE_RATE, MAX_INSTANT_NIGHTS } from "@/lib/config";
import {
  getNightlyPricesWithServiceClient,
  applyPriceBreakdown,
  getHourlyPricesWithServiceClient,
  applyHourlyPriceBreakdown,
  hourlyBreakdownHasUnavailable,
  type NightlyPrice,
  type HourlyPrice,
  type AvailabilityMode,
} from "@/lib/pricing";
import type { SpotMarker, ListingExtra, SelectedExtras } from "@/types";

async function computeTotalWithBreakdown(args: {
  listingId: string;
  listingPrice: number;
  spotMarkers: SpotMarker[] | null;
  listingExtras: ListingExtra[] | null;
  checkIn: string;
  checkOut: string;
  /** Hourly mode: full timestamps when set. Drives per-hour pricing. */
  checkInAt?: string | null;
  checkOutAt?: string | null;
  selectedSpotIds?: string[];
  selectedExtras?: SelectedExtras;
  /** Listing availability mode. Brukes for å avvise hourly bookings utenfor bånd. */
  availabilityMode?: AvailabilityMode;
}): Promise<{ total: number; breakdown: NightlyPrice[] | HourlyPrice[] | null; unavailable?: boolean }> {
  const isHourly = !!(args.checkInAt && args.checkOutAt);
  const start = new Date(args.checkIn);
  const end = new Date(args.checkOut);
  const nights = Math.max(1, Math.round((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)));
  const hours = isHourly
    ? Math.max(1, Math.round((new Date(args.checkOutAt!).getTime() - new Date(args.checkInAt!).getTime()) / (1000 * 60 * 60)))
    : 0;
  // Antall enheter for pris-beregning — timer for parkering per time, netter ellers.
  const units = isHourly ? hours : nights;
  // Extras betales per natt/døgn for daglige bookinger, men engangs for hourly (tunet pris-modell).
  const extrasUnits = isHourly ? 1 : nights;

  const selectedSpots = (args.spotMarkers || []).filter(
    (s) => s.id && args.selectedSpotIds?.includes(s.id),
  );
  const hasPerSpotPricing = selectedSpots.length > 0 && selectedSpots.some((s) => s.price != null);

  let baseTotal: number;
  let breakdown: NightlyPrice[] | HourlyPrice[] | null = null;

  if (hasPerSpotPricing) {
    baseTotal = selectedSpots.reduce((sum, s) => sum + (s.price ?? args.listingPrice) * units, 0);
  } else if (isHourly) {
    // Hourly listing: per-time-resolution med band-regler.
    // Per-spot scope: hvis kun én plass er valgt, send spotId så server filtrerer
    // bånd til den plassens regler (med fallback til listing-wide).
    const targetSpotId = args.selectedSpotIds?.length === 1 ? args.selectedSpotIds[0] : null;
    const hourlyBreakdown = await getHourlyPricesWithServiceClient(
      {
        listingId: args.listingId,
        checkInAt: args.checkInAt!,
        checkOutAt: args.checkOutAt!,
        basePrice: args.listingPrice,
        spotId: targetSpotId,
        availabilityMode: args.availabilityMode ?? "always",
      },
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
    );
    breakdown = hourlyBreakdown;
    if (hourlyBreakdownHasUnavailable(hourlyBreakdown)) {
      return { total: 0, breakdown, unavailable: true };
    }
    baseTotal = applyHourlyPriceBreakdown(hourlyBreakdown);
  } else {
    breakdown = await getNightlyPricesWithServiceClient(
      {
        listingId: args.listingId,
        checkIn: args.checkIn,
        checkOut: args.checkOut,
        basePrice: args.listingPrice,
      },
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
    );
    const perNight = applyPriceBreakdown(breakdown);
    baseTotal = selectedSpots.length > 1 ? perNight * selectedSpots.length : perNight;
  }

  let extrasTotal = 0;
  for (const entry of args.selectedExtras?.listing || []) {
    const canonical = (args.listingExtras || []).find((e) => e.id === entry.id);
    if (!canonical) continue;
    extrasTotal += canonical.price * (canonical.perNight ? extrasUnits : 1) * entry.quantity;
  }
  for (const [spotId, entries] of Object.entries(args.selectedExtras?.spots || {})) {
    const spot = selectedSpots.find((s) => s.id === spotId);
    if (!spot) continue;
    for (const entry of entries) {
      const canonical = (spot.extras || []).find((e) => e.id === entry.id);
      if (!canonical) continue;
      extrasTotal += canonical.price * (canonical.perNight ? extrasUnits : 1) * entry.quantity;
    }
  }

  const subtotal = baseTotal + extrasTotal;
  const total = subtotal + Math.round(subtotal * SERVICE_FEE_RATE);
  return { total, breakdown };
}

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
      checkIn,
      checkOut,
      checkInAt,
      checkOutAt,
      licensePlate,
      isRentalCar,
      selectedSpotIds,
      selectedExtras,
    } = body as {
      listingId: string;
      checkIn: string;
      checkOut: string;
      /** ISO timestamps for hourly bookings. NULL for daily/nightly. */
      checkInAt?: string | null;
      checkOutAt?: string | null;
      licensePlate?: string;
      isRentalCar?: boolean;
      selectedSpotIds?: string[];
      selectedExtras?: SelectedExtras;
    };

    if (!listingId || !checkIn || !checkOut) {
      return NextResponse.json({ error: "Mangler påkrevde felt" }, { status: 400 });
    }
    const isHourly = !!(checkInAt && checkOutAt);

    // Check availability
    const { data: listing } = await supabase
      .from("listings")
      .select("spots, host_id, title, price, spot_markers, extras, instant_booking, check_in_time, check_out_time, availability_mode")
      .eq("id", listingId)
      .single();

    if (!listing) {
      return NextResponse.json({ error: "Annonse ikke funnet" }, { status: 404 });
    }

    if (listing.host_id === user.id) {
      return NextResponse.json({ error: "Du kan ikke booke din egen annonse" }, { status: 400 });
    }

    // Rekalkulér totalen autoritativt server-side — klient sender ikke lenger beløp.
    const { total: totalPrice, breakdown, unavailable } = await computeTotalWithBreakdown({
      listingId,
      listingPrice: listing.price,
      spotMarkers: listing.spot_markers as SpotMarker[] | null,
      listingExtras: listing.extras as ListingExtra[] | null,
      checkIn,
      checkOut,
      checkInAt,
      checkOutAt,
      selectedSpotIds,
      selectedExtras,
      availabilityMode: (listing.availability_mode as AvailabilityMode) ?? "always",
    });

    if (unavailable) {
      return NextResponse.json(
        { error: "Plassen er ikke tilgjengelig på det valgte tidspunktet." },
        { status: 409 },
      );
    }

    // Stripe krever minst kr 3 for NOK-betalinger.
    if (totalPrice < 3) {
      return NextResponse.json(
        { error: "Bestillingen må være på minst 3 kr." },
        { status: 400 },
      );
    }

    // For hourly bookings er check_in og check_out som regel samme dato, så
    // den vanlige `.lt(check_in, checkOut)`-sjekken misser eksisterende hourly
    // på samme dag. Vi henter alle bookings i dato-rangen (inclusive) og
    // filtrerer i kode: hourly-mot-hourly via timestamp-overlap, hourly-mot-
    // daily via dato-medlemskap.
    const isHourlyCheck = isHourly && checkInAt && checkOutAt;
    const overlapQuery = supabase
      .from("bookings")
      .select("selected_spot_ids, check_in, check_out, check_in_at, check_out_at")
      .eq("listing_id", listingId)
      .in("status", ["confirmed", "pending", "requested"]);

    const { data: rawOverlap } = isHourlyCheck
      ? await overlapQuery.lte("check_in", checkOut).gte("check_out", checkIn)
      : await overlapQuery.lt("check_in", checkOut).gt("check_out", checkIn);

    const overlappingBookings = (rawOverlap || []).filter((b) => {
      if (!isHourlyCheck) return true;  // daily-flyt: SQL har allerede filtrert riktig
      if (b.check_in_at && b.check_out_at) {
        // Hourly-mot-hourly: krever ekte tidsoverlapp
        const newIn = new Date(checkInAt!).getTime();
        const newOut = new Date(checkOutAt!).getTime();
        const bIn = new Date(b.check_in_at).getTime();
        const bOut = new Date(b.check_out_at).getTime();
        return newIn < bOut && newOut > bIn;
      }
      // Hourly-mot-daily: daily blokkerer [check_in, check_out)-rangen
      return checkIn >= b.check_in && checkIn < b.check_out;
    });

    const bookedCount = overlappingBookings.reduce((sum, row) => {
      const ids = row.selected_spot_ids as string[] | null;
      return sum + (ids && ids.length > 0 ? ids.length : 1);
    }, 0);

    const available = listing.spots - bookedCount;
    if (available <= 0) {
      return NextResponse.json({ error: "Ingen ledige plasser for valgte datoer" });
    }

    // Sjekk per-spot-konflikt
    if (selectedSpotIds && selectedSpotIds.length > 0) {
      const alreadyBooked = new Set<string>();
      for (const row of overlappingBookings || []) {
        const ids = row.selected_spot_ids as string[] | null;
        (ids || []).forEach((id) => alreadyBooked.add(id));
      }
      const conflict = selectedSpotIds.find((id) => alreadyBooked.has(id));
      if (conflict) {
        return NextResponse.json({ error: "En eller flere av de valgte plassene er allerede booket. Velg andre plasser." });
      }

      // Sjekk manuelt blokkerte datoer per plass.
      // Hourly bookings har checkIn === checkOut (samme dag) — while-løkken
      // gir tom liste, så vi inkluderer datoen eksplisitt i hourly-flyt.
      const spotMarkers = (listing.spot_markers as SpotMarker[] | null) || [];
      const datesInRange: string[] = [];
      if (isHourlyCheck) {
        datesInRange.push(checkIn);
      } else {
        const cursor = new Date(checkIn);
        const end = new Date(checkOut);
        while (cursor < end) {
          const y = cursor.getFullYear();
          const m = String(cursor.getMonth() + 1).padStart(2, "0");
          const d = String(cursor.getDate()).padStart(2, "0");
          datesInRange.push(`${y}-${m}-${d}`);
          cursor.setDate(cursor.getDate() + 1);
        }
      }
      for (const spotId of selectedSpotIds) {
        const spot = spotMarkers.find((s) => s.id === spotId);
        if (spot?.blockedDates?.some((d) => datesInRange.includes(d))) {
          return NextResponse.json({ error: `Plass "${spot.label ?? spotId}" er ikke tilgjengelig for valgte datoer.` });
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

    // Max-dager-regelen: opphold over MAX_INSTANT_NIGHTS krever godkjenning uansett.
    const nights = Math.max(
      1,
      Math.round((new Date(checkOut).getTime() - new Date(checkIn).getTime()) / 86400000),
    );
    const exceedsInstantLimit = nights > MAX_INSTANT_NIGHTS;
    const requiresApproval = listing.instant_booking === false || exceedsInstantLimit;
    const approvalDeadline = requiresApproval
      ? new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
      : null;

    // Insert booking
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .insert({
        user_id: user.id,
        listing_id: listingId,
        check_in: checkIn,
        check_out: checkOut,
        // Hourly bookings: lagre faktisk timestamp-vindu i tillegg til check_in/check_out (samme dag).
        check_in_at: isHourly ? checkInAt : null,
        check_out_at: isHourly ? checkOutAt : null,
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
    const { data: overlapping } = await supabase
      .from("bookings")
      .select("id, created_at, selected_spot_ids")
      .eq("listing_id", listingId)
      .in("status", ["pending", "requested", "confirmed"])
      .lt("check_in", checkOut)
      .gt("check_out", checkIn)
      .order("created_at", { ascending: true });

    if (overlapping) {
      const totalSpots = (listing.spots as number) || 1;
      if (selectedSpotIds && selectedSpotIds.length > 0) {
        const otherSpots = new Set<string>();
        for (const o of overlapping) {
          if (o.id === booking.id) continue;
          if (new Date(o.created_at).getTime() >= Date.now() - 60000) {
            for (const sid of (o.selected_spot_ids as string[] | null) || []) {
              otherSpots.add(sid);
            }
          }
        }
        const conflict = selectedSpotIds.find((id: string) => otherSpots.has(id));
        if (conflict) {
          await supabase.from("bookings").delete().eq("id", booking.id);
          return NextResponse.json({ error: "Plassen ble booket av en annen bruker akkurat nå. Velg en annen plass." }, { status: 409 });
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
