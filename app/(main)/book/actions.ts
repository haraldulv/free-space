"use server";

import { createClient } from "@/lib/supabase/server";
import { stripe } from "@/lib/stripe";
import { getAvailableSpots } from "@/lib/supabase/listings";
import { SERVICE_FEE_RATE } from "@/lib/config";

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
}): Promise<{ bookingId?: string; clientSecret?: string; error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    // Check availability before creating booking
    const available = await getAvailableSpots(data.listingId, data.checkIn, data.checkOut);
    if (available <= 0) return { error: "Ingen ledige plasser for valgte datoer" };

    // Get listing to find host
    const { data: listing } = await supabase
      .from("listings")
      .select("host_id, title")
      .eq("id", data.listingId)
      .single();

    if (!listing) return { error: "Annonse ikke funnet" };

    // Verify host has Stripe Connect
    const { data: hostProfile } = await supabase
      .from("profiles")
      .select("stripe_account_id, stripe_onboarding_complete")
      .eq("id", listing.host_id)
      .single();

    if (!hostProfile?.stripe_account_id || !hostProfile?.stripe_onboarding_complete) {
      return { error: "Utleier har ikke satt opp utbetalinger ennå. Prøv igjen senere." };
    }

    // Insert booking with pending status
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
      })
      .select("id")
      .single();

    if (bookingError) return { error: bookingError.message };

    // Create Stripe PaymentIntent (amount in øre)
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

    // Save payment intent ID to booking
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

export async function cancelBookingAction(bookingId: string): Promise<{ error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, user_id, payment_intent_id, payment_status, transfer_status, stripe_transfer_id")
      .eq("id", bookingId)
      .single();

    if (!booking) return { error: "Bestilling ikke funnet" };
    if (booking.user_id !== user.id) return { error: "Ikke tilgang" };

    // Reverse transfer if already paid out to host
    if (booking.transfer_status === "transferred" && booking.stripe_transfer_id) {
      await stripe.transfers.createReversal(booking.stripe_transfer_id);
    }

    // Refund if paid
    if (booking.payment_status === "paid" && booking.payment_intent_id) {
      await stripe.refunds.create({
        payment_intent: booking.payment_intent_id,
      });
    }

    await supabase
      .from("bookings")
      .update({
        status: "cancelled",
        payment_status: "refunded",
        transfer_status: booking.transfer_status === "transferred" ? "reversed" : "not_applicable",
      })
      .eq("id", bookingId);

    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}
