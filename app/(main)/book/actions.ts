"use server";

import { createClient } from "@/lib/supabase/server";
import { stripe } from "@/lib/stripe";
import { getAvailableSpots } from "@/lib/supabase/listings";
import { SERVICE_FEE_RATE } from "@/lib/config";
import { computeRefund, type CancelledBy } from "@/lib/cancellation";
import { sendCancellationEmail } from "@/lib/email";
import { createClient as createServiceClient } from "@supabase/supabase-js";

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
}): Promise<{ bookingId?: string; clientSecret?: string; error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    const available = await getAvailableSpots(data.listingId, data.checkIn, data.checkOut);
    if (available <= 0) return { error: "Ingen ledige plasser for valgte datoer" };

    const { data: listing } = await supabase
      .from("listings")
      .select("host_id, title")
      .eq("id", data.listingId)
      .single();

    if (!listing) return { error: "Annonse ikke funnet" };

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
        total_price: data.totalPrice,
        status: "pending",
        payment_status: "pending",
        host_id: listing.host_id,
        license_plate: data.licensePlate || null,
        is_rental_car: data.isRentalCar || false,
      })
      .select("id")
      .single();

    if (bookingError) return { error: bookingError.message };

    const paymentIntent = await stripe.paymentIntents.create({
      amount: data.totalPrice * 100,
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
      if (guestEmail) sendCancellationEmail(guestEmail, { name: guestName, ...emailData }).catch(console.error);
      if (hostEmail && cancelledBy === "guest") {
        const { data: hostProfile } = await db.from("profiles").select("full_name").eq("id", booking.host_id).single();
        sendCancellationEmail(hostEmail, { name: hostProfile?.full_name || "Utleier", ...emailData }).catch(console.error);
      }
    } catch { /* email errors should not block cancellation */ }

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
