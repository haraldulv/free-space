"use server";

import { createClient } from "@/lib/supabase/server";
import { stripe } from "@/lib/stripe";
import { getAvailableSpots, getBookedSpotIds } from "@/lib/supabase/listings";
import { SERVICE_FEE_RATE, MAX_INSTANT_NIGHTS } from "@/lib/config";
import { computeRefund, type CancelledBy } from "@/lib/cancellation";
import {
  sendCancellationEmail,
  sendBookingApprovedToGuest,
  sendBookingDeclinedToGuest,
} from "@/lib/email";
import { sendPushToUser } from "@/lib/push";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import { getNightlyPrices, applyPriceBreakdown, type NightlyPrice } from "@/lib/pricing";
import type { SpotMarker, ListingExtra, SelectedExtras, SelectedExtraEntry } from "@/types";

type SelectedExtrasClient = {
  listing?: SelectedExtraEntry[];
  spots?: Record<string, SelectedExtraEntry[]>;
};

/**
 * Autoritativ pris-utregning server-side. Klient sender inn ønsket total,
 * men vi rekalkulerer basert på DB-en så Stripe-beløpet aldri avviker fra
 * det annonsen faktisk koster.
 *
 * For listings uten per-spot-pricing brukes pricing-engine (regler + overrides).
 * For listings med per-spot-pricing brukes flat spot-pris × nights (rules
 * gjelder ikke når host eksplisitt har satt pris per plass).
 */
async function computeAuthoritativeTotal(args: {
  listingId: string;
  listingPrice: number;
  spotMarkers: SpotMarker[] | null;
  listingExtras: ListingExtra[] | null;
  checkIn: string;
  checkOut: string;
  selectedSpotIds?: string[];
  selectedExtras?: SelectedExtrasClient;
}): Promise<{ total: number; baseTotal: number; extrasTotal: number; serviceFee: number; breakdown: NightlyPrice[] | null }> {
  const start = new Date(args.checkIn);
  const end = new Date(args.checkOut);
  const nights = Math.max(1, Math.round((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)));

  const selectedSpots = (args.spotMarkers || []).filter(
    (s) => s.id && args.selectedSpotIds?.includes(s.id),
  );

  const hasPerSpotPricing = selectedSpots.length > 0 && selectedSpots.some((s) => s.price != null);

  let baseTotal: number;
  let breakdown: NightlyPrice[] | null = null;

  if (hasPerSpotPricing) {
    baseTotal = selectedSpots.reduce((sum, s) => sum + (s.price ?? args.listingPrice) * nights, 0);
  } else if (selectedSpots.length > 1) {
    // Flere plasser, uniform pris → rules ganget med antall plasser
    breakdown = await getNightlyPrices({
      listingId: args.listingId,
      checkIn: args.checkIn,
      checkOut: args.checkOut,
      basePrice: args.listingPrice,
    });
    const perNightTotal = applyPriceBreakdown(breakdown);
    baseTotal = perNightTotal * selectedSpots.length;
  } else {
    // Ingen eller én plass → ren breakdown gjelder
    breakdown = await getNightlyPrices({
      listingId: args.listingId,
      checkIn: args.checkIn,
      checkOut: args.checkOut,
      basePrice: args.listingPrice,
    });
    baseTotal = applyPriceBreakdown(breakdown);
  }

  let extrasTotal = 0;
  for (const entry of args.selectedExtras?.listing || []) {
    const canonical = (args.listingExtras || []).find((e) => e.id === entry.id);
    if (!canonical) continue;
    extrasTotal += canonical.price * (canonical.perNight ? nights : 1) * entry.quantity;
  }
  for (const [spotId, entries] of Object.entries(args.selectedExtras?.spots || {})) {
    const spot = selectedSpots.find((s) => s.id === spotId);
    if (!spot) continue;
    for (const entry of entries) {
      const canonical = (spot.extras || []).find((e) => e.id === entry.id);
      if (!canonical) continue;
      extrasTotal += canonical.price * (canonical.perNight ? nights : 1) * entry.quantity;
    }
  }

  const subtotal = baseTotal + extrasTotal;
  const serviceFee = Math.round(subtotal * SERVICE_FEE_RATE);
  const total = subtotal + serviceFee;

  return { total, baseTotal, extrasTotal, serviceFee, breakdown };
}

async function getAuthUser() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");
  return { supabase, user };
}

export async function previewPriceBreakdownAction(data: {
  listingId: string;
  checkIn: string;
  checkOut: string;
}): Promise<{ breakdown: NightlyPrice[] | null; nightlyTotal: number }> {
  const supabase = await createClient();
  const { data: listing } = await supabase
    .from("listings")
    .select("price")
    .eq("id", data.listingId)
    .single();
  if (!listing) return { breakdown: null, nightlyTotal: 0 };
  const breakdown = await getNightlyPrices({
    listingId: data.listingId,
    checkIn: data.checkIn,
    checkOut: data.checkOut,
    basePrice: listing.price as number,
  });
  return { breakdown, nightlyTotal: applyPriceBreakdown(breakdown) };
}

export async function checkAvailabilityAction(data: {
  listingId: string;
  checkIn: string;
  checkOut: string;
}): Promise<{ availableSpots: number; totalSpots: number }> {
  const supabase = await createClient();

  const { data: listing } = await supabase
    .from("listings")
    .select("spots")
    .eq("id", data.listingId)
    .single();

  const totalSpots = listing?.spots || 1;
  const availableSpots = await getAvailableSpots(data.listingId, data.checkIn, data.checkOut);

  return { availableSpots, totalSpots };
}

export async function createBookingAction(data: {
  listingId: string;
  checkIn: string;
  checkOut: string;
  totalPrice: number;
  licensePlate?: string;
  isRentalCar?: boolean;
  selectedSpotIds?: string[];
  selectedExtras?: SelectedExtras;
}): Promise<{ bookingId?: string; clientSecret?: string; requiresApproval?: boolean; error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    const available = await getAvailableSpots(data.listingId, data.checkIn, data.checkOut);
    if (available <= 0) return { error: "Ingen ledige plasser for valgte datoer" };

    // Sjekk at bruker ikke prøver å booke sin egen annonse
    const { data: ownerCheck } = await supabase
      .from("listings")
      .select("host_id")
      .eq("id", data.listingId)
      .single();
    if (ownerCheck?.host_id === user.id) {
      return { error: "Du kan ikke booke din egen annonse" };
    }

    // Sjekk at ingen av de valgte plassene allerede er booket i samme periode
    if (data.selectedSpotIds && data.selectedSpotIds.length > 0) {
      const bookedSpotIds = await getBookedSpotIds(data.listingId, data.checkIn, data.checkOut);
      const conflict = data.selectedSpotIds.find((id) => bookedSpotIds.has(id));
      if (conflict) {
        return { error: "En eller flere av de valgte plassene er allerede booket. Velg andre plasser." };
      }
    }

    const { data: listing } = await supabase
      .from("listings")
      .select("host_id, title, price, spot_markers, extras, instant_booking, check_in_time, check_out_time, spots")
      .eq("id", data.listingId)
      .single();

    if (!listing) return { error: "Annonse ikke funnet" };

    // Sjekk at valgte plasser ikke har manuell blokkering i perioden
    if (data.selectedSpotIds && data.selectedSpotIds.length > 0) {
      const spotMarkers = (listing.spot_markers as SpotMarker[] | null) || [];
      const datesInRange: string[] = [];
      const cursor = new Date(data.checkIn);
      const end = new Date(data.checkOut);
      while (cursor < end) {
        const y = cursor.getFullYear();
        const m = String(cursor.getMonth() + 1).padStart(2, "0");
        const d = String(cursor.getDate()).padStart(2, "0");
        datesInRange.push(`${y}-${m}-${d}`);
        cursor.setDate(cursor.getDate() + 1);
      }
      for (const spotId of data.selectedSpotIds) {
        const spot = spotMarkers.find((s) => s.id === spotId);
        if (spot?.blockedDates?.some((d) => datesInRange.includes(d))) {
          return { error: `Plass "${spot.label ?? spotId}" er ikke tilgjengelig for valgte datoer.` };
        }
      }
    }

    // Autoritativ rekalkulering — server bestemmer beløpet, ikke klient.
    const { total: authoritativeTotal, breakdown } = await computeAuthoritativeTotal({
      listingId: data.listingId,
      listingPrice: listing.price,
      spotMarkers: listing.spot_markers as SpotMarker[] | null,
      listingExtras: listing.extras as ListingExtra[] | null,
      checkIn: data.checkIn,
      checkOut: data.checkOut,
      selectedSpotIds: data.selectedSpotIds,
      selectedExtras: data.selectedExtras as SelectedExtrasClient | undefined,
    });

    // Stripe krever minst kr 3 for NOK-betalinger.
    if (authoritativeTotal < 3) {
      return { error: "Bestillingen må være på minst 3 kr." };
    }

    const { data: hostProfile } = await supabase
      .from("profiles")
      .select("stripe_account_id, stripe_onboarding_complete")
      .eq("id", listing.host_id)
      .single();

    if (!hostProfile?.stripe_account_id || !hostProfile?.stripe_onboarding_complete) {
      return { error: "Utleier har ikke satt opp utbetalinger ennå. Prøv igjen senere." };
    }

    // Opphold over MAX_INSTANT_NIGHTS krever alltid godkjenning — selv på
    // instant-annonser. Beskytter host mot langtidsopphold de ikke aktivt har sagt ja til.
    const nights = Math.max(
      1,
      Math.round(
        (new Date(data.checkOut).getTime() - new Date(data.checkIn).getTime()) / 86400000,
      ),
    );
    const exceedsInstantLimit = nights > MAX_INSTANT_NIGHTS;
    const requiresApproval = listing.instant_booking === false || exceedsInstantLimit;
    const approvalDeadline = requiresApproval
      ? new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()
      : null;

    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .insert({
        user_id: user.id,
        listing_id: data.listingId,
        check_in: data.checkIn,
        check_out: data.checkOut,
        // Snapshot tidspunkter — hvis host endrer listing.check_in_time/check_out_time
        // senere skal eksisterende bookinger beholde sin opprinnelige avtale.
        check_in_time: (listing.check_in_time as string) || "15:00",
        check_out_time: (listing.check_out_time as string) || "11:00",
        total_price: authoritativeTotal,
        status: "pending",
        payment_status: "pending",
        host_id: listing.host_id,
        license_plate: data.licensePlate || null,
        is_rental_car: data.isRentalCar || false,
        approval_deadline: approvalDeadline,
        selected_spot_ids: data.selectedSpotIds && data.selectedSpotIds.length > 0 ? data.selectedSpotIds : null,
        selected_extras: data.selectedExtras && (data.selectedExtras.listing?.length || Object.keys(data.selectedExtras.spots || {}).length)
          ? data.selectedExtras
          : null,
        // Snapshot per-natt pris-breakdown — host-endringer av regler
        // skal ikke ramme eksisterende bookinger retroaktivt.
        price_breakdown: breakdown,
      })
      .select("id")
      .single();

    if (bookingError) return { error: bookingError.message };

    // Post-insert overlap-verifisering: hvis to bookinger slapp gjennom
    // availability-sjekken på nesten samme tidspunkt, sjekk at totalt antall
    // bookinger ikke overstiger listing.spots. Taperen (den med nyeste
    // created_at) rulles tilbake. Dette er pragmatisk beskyttelse uten å
    // kreve DB-transaksjon.
    const { data: overlapping } = await supabase
      .from("bookings")
      .select("id, created_at, selected_spot_ids")
      .eq("listing_id", data.listingId)
      .in("status", ["pending", "requested", "confirmed"])
      .lt("check_in", data.checkOut)
      .gt("check_out", data.checkIn)
      .order("created_at", { ascending: true });

    if (overlapping) {
      const totalSpots = (listing.spots as number) || 1;
      if (data.selectedSpotIds && data.selectedSpotIds.length > 0) {
        // Spot-level check: er noen spesifikke plasser doble?
        const otherSpots = new Set<string>();
        for (const o of overlapping) {
          if (o.id === booking.id) continue;
          if (new Date(o.created_at).getTime() >= new Date().getTime() - 60000) {
            for (const sid of (o.selected_spot_ids as string[] | null) || []) {
              otherSpots.add(sid);
            }
          }
        }
        const conflict = data.selectedSpotIds.find((id) => otherSpots.has(id));
        if (conflict) {
          await supabase.from("bookings").delete().eq("id", booking.id);
          return { error: "Plassen ble booket av en annen bruker akkurat nå. Velg en annen plass." };
        }
      } else {
        // Listing-level check: totalt antall bookinger må ikke overstige spots.
        if (overlapping.length > totalSpots) {
          // Vi er taperen hvis vår created_at er den nyeste
          const ourIdx = overlapping.findIndex((o) => o.id === booking.id);
          if (ourIdx >= totalSpots) {
            await supabase.from("bookings").delete().eq("id", booking.id);
            return { error: "Annonsen ble fullbooket av andre brukere akkurat nå. Prøv en annen dato." };
          }
        }
      }
    }

    // Sørg for at det finnes en samtale mellom gjest og host — ingen dead links.
    // Ikke-blokkende: feil her skal ikke stoppe booking.
    await supabase
      .from("conversations")
      .upsert(
        {
          listing_id: data.listingId,
          guest_id: user.id,
          host_id: listing.host_id,
          booking_id: booking.id,
        },
        { onConflict: "listing_id,guest_id", ignoreDuplicates: true },
      );

    const paymentIntent = await stripe.paymentIntents.create({
      amount: authoritativeTotal * 100,
      currency: "nok",
      capture_method: requiresApproval ? "manual" : "automatic",
      metadata: {
        bookingId: booking.id,
        listingId: data.listingId,
        userId: user.id,
        listingTitle: listing.title,
        hostStripeAccountId: hostProfile.stripe_account_id,
        serviceFeeRate: String(SERVICE_FEE_RATE),
        requiresApproval: requiresApproval ? "true" : "false",
      },
    });

    await supabase
      .from("bookings")
      .update({ payment_intent_id: paymentIntent.id })
      .eq("id", booking.id);

    return {
      bookingId: booking.id,
      clientSecret: paymentIntent.client_secret!,
      requiresApproval,
    };
  } catch (err) {
    console.error("createBookingAction error:", err);
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function cancelBookingAction(
  bookingId: string,
  reason?: string
): Promise<{ error?: string; refundAmount?: number }> {
  try {
    const { supabase, user } = await getAuthUser();

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, listing_id, check_in, check_out, total_price, payment_intent_id, payment_status, transfer_status, stripe_transfer_id, status")
      .eq("id", bookingId)
      .single();

    if (!booking) return { error: "Bestilling ikke funnet" };
    if (booking.status === "cancelled") return { error: "Allerede kansellert" };

    const isGuest = booking.user_id === user.id;
    const isHost = booking.host_id === user.id;
    if (!isGuest && !isHost) return { error: "Ikke tilgang" };

    const cancelledBy: CancelledBy = isHost ? "host" : "guest";
    const result = computeRefund(booking.total_price, booking.check_in, cancelledBy);

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
        cancelled_by: cancelledBy,
        cancellation_reason: reason || null,
        refund_amount: result.refundAmount,
      })
      .eq("id", bookingId);

    // Send cancellation emails
    try {
      const db = createServiceClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);
      const { data: listing } = await db.from("listings").select("title").eq("id", booking.listing_id).single();
      const [guestAuth, hostAuth] = await Promise.all([
        db.auth.admin.getUserById(booking.user_id),
        booking.host_id ? db.auth.admin.getUserById(booking.host_id) : null,
      ]);
      const guestEmail = guestAuth.data.user?.email;
      const hostEmail = hostAuth?.data.user?.email;
      const guestName = guestAuth.data.user?.user_metadata?.full_name || "Gjest";
      const emailData = {
        listingTitle: listing?.title || "en plass",
        checkIn: booking.check_in,
        checkOut: booking.check_out || booking.check_in,
        refundAmount: result.refundAmount,
        cancelledBy,
      };
      const listingTitle = listing?.title || "en plass";
      const refundSuffix = result.refundAmount > 0 ? ` Refusjon: ${result.refundAmount} kr.` : "";
      const cancelSends: Promise<unknown>[] = [];
      if (guestEmail) {
        cancelSends.push(
          sendCancellationEmail(guestEmail, { name: guestName, ...emailData })
            .catch((err) => console.error("[Email] cancel guest failed:", err)),
        );
      }
      if (hostEmail && cancelledBy === "guest") {
        const { data: hostProfile } = await db.from("profiles").select("full_name").eq("id", booking.host_id).single();
        cancelSends.push(
          sendCancellationEmail(hostEmail, { name: hostProfile?.full_name || "Utleier", ...emailData })
            .catch((err) => console.error("[Email] cancel host failed:", err)),
        );
      }
      // Push til den motparten som ikke avbestilte selv.
      if (cancelledBy === "host") {
        cancelSends.push(
          sendPushToUser(
            booking.user_id,
            "Booking kansellert",
            `Utleier har kansellert ${listingTitle}.${refundSuffix}`,
            { bookingId: booking.id, type: "booking_cancelled" },
          ).catch((err) => console.error("[Push] cancel guest failed:", err)),
        );
      } else if (cancelledBy === "guest" && booking.host_id) {
        cancelSends.push(
          sendPushToUser(
            booking.host_id,
            "Booking kansellert",
            `Gjesten har kansellert bookingen av ${listingTitle}.`,
            { bookingId: booking.id, type: "booking_cancelled" },
          ).catch((err) => console.error("[Push] cancel host failed:", err)),
        );
      }
      await Promise.all(cancelSends);
    } catch { /* email/push errors should not block cancellation */ }

    return { refundAmount: result.refundAmount };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

/**
 * Host godkjenner en booking-forespørsel.
 * Stripe captures den autoriserte PaymentIntent — succeeds-webhook oppdaterer
 * deretter status til 'confirmed' + payment_status='paid'.
 */
export async function approveBookingAction(bookingId: string): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, host_id, status, payment_intent_id, approval_deadline, user_id, listing_id, check_in, check_out, total_price")
      .eq("id", bookingId)
      .single();

    if (!booking) return { error: "Bestilling ikke funnet" };
    if (booking.host_id !== user.id) return { error: "Ikke tilgang" };
    if (booking.status !== "requested") return { error: "Bookingen kan ikke godkjennes" };
    if (booking.approval_deadline && new Date(booking.approval_deadline) < new Date()) {
      return { error: "Tidsfristen for å godkjenne har gått ut" };
    }
    if (!booking.payment_intent_id) return { error: "Mangler betalingsinformasjon" };

    await stripe.paymentIntents.capture(booking.payment_intent_id);

    // Sett status optimistisk så UI oppdateres umiddelbart. Webhooken vil
    // sette samme verdi når payment_intent.succeeded fyrer.
    await supabase
      .from("bookings")
      .update({
        status: "confirmed",
        payment_status: "paid",
        host_responded_at: new Date().toISOString(),
      })
      .eq("id", bookingId);

    // Push + e-post til gjest
    try {
      const db = createServiceClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);
      const { data: listing } = await db.from("listings").select("title, images").eq("id", booking.listing_id).single();
      const guestAuth = await db.auth.admin.getUserById(booking.user_id);
      const guestEmail = guestAuth.data.user?.email;
      const guestName = guestAuth.data.user?.user_metadata?.full_name || "Gjest";
      const listingTitle = listing?.title || "en plass";

      const approveSends: Promise<unknown>[] = [
        sendPushToUser(
          booking.user_id,
          "Forespørselen er godkjent!",
          `Utleier har godkjent bookingen av ${listingTitle}.`,
          { bookingId: booking.id, type: "booking_confirmed" },
        ).catch((err) => console.error("[Push] approve failed:", err)),
      ];

      if (guestEmail) {
        approveSends.push(
          sendBookingApprovedToGuest(guestEmail, {
            guestName,
            listingTitle,
            listingId: booking.listing_id,
            listingImage: listing?.images?.[0] ?? null,
            checkIn: booking.check_in,
            checkOut: booking.check_out,
            totalPrice: booking.total_price,
          }).catch((err) => console.error("[Email] approve failed:", err)),
        );
      }
      await Promise.all(approveSends);
    } catch { /* ikke blokker */ }

    return {};
  } catch (err) {
    console.error("approveBookingAction error:", err);
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

/**
 * Host avviser en booking-forespørsel (eller cron auto-avviser ved timeout).
 * Stripe canceller den autoriserte PaymentIntent — pengene frigjøres.
 */
export async function declineBookingAction(
  bookingId: string,
  options?: { autoDeclined?: boolean; allowCron?: boolean },
): Promise<{ error?: string }> {
  try {
    const supabase = options?.allowCron
      ? createServiceClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!)
      : (await getAuthUser()).supabase;
    const userId = options?.allowCron ? null : (await getAuthUser()).user.id;

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, host_id, status, payment_intent_id, user_id, listing_id, check_in, check_out")
      .eq("id", bookingId)
      .single();

    if (!booking) return { error: "Bestilling ikke funnet" };
    if (!options?.allowCron && booking.host_id !== userId) return { error: "Ikke tilgang" };
    if (booking.status !== "requested") return { error: "Bookingen kan ikke avvises" };

    if (booking.payment_intent_id) {
      try {
        await stripe.paymentIntents.cancel(booking.payment_intent_id);
      } catch (err) {
        // Hvis PI allerede er cancelled (idempotent retry), fortsett.
        console.warn("paymentIntents.cancel:", err);
      }
    }

    await supabase
      .from("bookings")
      .update({
        status: "cancelled",
        payment_status: "refunded",
        cancelled_at: new Date().toISOString(),
        cancelled_by: "host",
        cancellation_reason: options?.autoDeclined ? "auto_declined_timeout" : "host_declined",
        host_responded_at: new Date().toISOString(),
      })
      .eq("id", bookingId);

    // Push + e-post til gjest
    try {
      const db = createServiceClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);
      const { data: listing } = await db.from("listings").select("title").eq("id", booking.listing_id).single();
      const guestAuth = await db.auth.admin.getUserById(booking.user_id);
      const guestEmail = guestAuth.data.user?.email;
      const guestName = guestAuth.data.user?.user_metadata?.full_name || "Gjest";
      const listingTitle = listing?.title || "en plass";

      const pushTitle = options?.autoDeclined
        ? "Forespørselen utløp"
        : "Forespørselen ble avvist";
      const pushBody = options?.autoDeclined
        ? `Utleier rakk ikke å svare på ${listingTitle}. Beløpet er frigjort.`
        : `Utleier kunne ikke ta imot ${listingTitle}. Beløpet er frigjort.`;

      const declineSends: Promise<unknown>[] = [
        sendPushToUser(
          booking.user_id,
          pushTitle,
          pushBody,
          { bookingId: booking.id, type: "booking_declined" },
        ).catch((err) => console.error("[Push] decline failed:", err)),
      ];

      if (guestEmail) {
        declineSends.push(
          sendBookingDeclinedToGuest(guestEmail, {
            guestName,
            listingTitle,
            checkIn: booking.check_in,
            checkOut: booking.check_out,
            autoDeclined: !!options?.autoDeclined,
          }).catch((err) => console.error("[Email] decline failed:", err)),
        );
      }
      await Promise.all(declineSends);
    } catch { /* ikke blokker */ }

    return {};
  } catch (err) {
    console.error("declineBookingAction error:", err);
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}

export async function getCancellationPreviewAction(bookingId: string): Promise<{
  refundAmount?: number;
  policyLabel?: string;
  error?: string;
}> {
  try {
    const { supabase, user } = await getAuthUser();

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, check_in, total_price, status")
      .eq("id", bookingId)
      .single();

    if (!booking) return { error: "Bestilling ikke funnet" };
    if (booking.status === "cancelled") return { error: "Allerede kansellert" };

    const isHost = booking.host_id === user.id;
    const cancelledBy: CancelledBy = isHost ? "host" : "guest";
    const result = computeRefund(booking.total_price, booking.check_in, cancelledBy);

    return { refundAmount: result.refundAmount, policyLabel: result.policyLabel };
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}
