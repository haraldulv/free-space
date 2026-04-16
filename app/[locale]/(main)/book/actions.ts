"use server";

import { createClient } from "@/lib/supabase/server";
import { stripe } from "@/lib/stripe";
import { getAvailableSpots, getBookedSpotIds } from "@/lib/supabase/listings";
import { SERVICE_FEE_RATE } from "@/lib/config";
import { computeRefund, type CancelledBy } from "@/lib/cancellation";
import { sendCancellationEmail } from "@/lib/email";
import { sendPushToUser } from "@/lib/push";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import type { SpotMarker, ListingExtra, SelectedExtras, SelectedExtraEntry } from "@/types";

type SelectedExtrasClient = {
  listing?: SelectedExtraEntry[];
  spots?: Record<string, SelectedExtraEntry[]>;
};

/**
 * Autoritativ pris-utregning server-side. Klient sender inn ønsket total,
 * men vi rekalkulerer basert på DB-en så Stripe-beløpet aldri avviker fra
 * det annonsen faktisk koster.
 */
function computeAuthoritativeTotal(args: {
  listingPrice: number;
  spotMarkers: SpotMarker[] | null;
  listingExtras: ListingExtra[] | null;
  checkIn: string;
  checkOut: string;
  selectedSpotIds?: string[];
  selectedExtras?: SelectedExtrasClient;
}): { total: number; baseTotal: number; extrasTotal: number; serviceFee: number } {
  const start = new Date(args.checkIn);
  const end = new Date(args.checkOut);
  const nights = Math.max(1, Math.round((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)));

  const selectedSpots = (args.spotMarkers || []).filter(
    (s) => s.id && args.selectedSpotIds?.includes(s.id),
  );

  const baseTotal = selectedSpots.length > 0
    ? selectedSpots.reduce((sum, s) => sum + (s.price ?? args.listingPrice) * nights, 0)
    : args.listingPrice * nights;

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

  return { total, baseTotal, extrasTotal, serviceFee };
}

async function getAuthUser() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");
  return { supabase, user };
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
}): Promise<{ bookingId?: string; clientSecret?: string; error?: string }> {
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
      .select("host_id, title, price, spot_markers, extras")
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
    const { total: authoritativeTotal } = computeAuthoritativeTotal({
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

    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .insert({
        user_id: user.id,
        listing_id: data.listingId,
        check_in: data.checkIn,
        check_out: data.checkOut,
        total_price: authoritativeTotal,
        status: "pending",
        payment_status: "pending",
        host_id: listing.host_id,
        license_plate: data.licensePlate || null,
        is_rental_car: data.isRentalCar || false,
        selected_spot_ids: data.selectedSpotIds && data.selectedSpotIds.length > 0 ? data.selectedSpotIds : null,
        selected_extras: data.selectedExtras && (data.selectedExtras.listing?.length || Object.keys(data.selectedExtras.spots || {}).length)
          ? data.selectedExtras
          : null,
      })
      .select("id")
      .single();

    if (bookingError) return { error: bookingError.message };

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
      metadata: {
        bookingId: booking.id,
        listingId: data.listingId,
        userId: user.id,
        listingTitle: listing.title,
        hostStripeAccountId: hostProfile.stripe_account_id,
        serviceFeeRate: String(SERVICE_FEE_RATE),
      },
    });

    await supabase
      .from("bookings")
      .update({ payment_intent_id: paymentIntent.id })
      .eq("id", booking.id);

    return {
      bookingId: booking.id,
      clientSecret: paymentIntent.client_secret!,
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
      if (guestEmail) sendCancellationEmail(guestEmail, { name: guestName, ...emailData }).catch(console.error);
      if (hostEmail && cancelledBy === "guest") {
        const { data: hostProfile } = await db.from("profiles").select("full_name").eq("id", booking.host_id).single();
        sendCancellationEmail(hostEmail, { name: hostProfile?.full_name || "Utleier", ...emailData }).catch(console.error);
      }
      // Push til den motparten som ikke avbestilte selv.
      if (cancelledBy === "host") {
        sendPushToUser(
          booking.user_id,
          "Booking kansellert",
          `Utleier har kansellert ${listingTitle}.${refundSuffix}`,
          { bookingId: booking.id, type: "booking_cancelled" },
        ).catch(console.error);
      } else if (cancelledBy === "guest" && booking.host_id) {
        sendPushToUser(
          booking.host_id,
          "Booking kansellert",
          `Gjesten har kansellert bookingen av ${listingTitle}.`,
          { bookingId: booking.id, type: "booking_cancelled" },
        ).catch(console.error);
      }
    } catch { /* email/push errors should not block cancellation */ }

    return { refundAmount: result.refundAmount };
  } catch (err) {
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
