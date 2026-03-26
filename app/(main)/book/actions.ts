"use server";

import { createClient } from "@/lib/supabase/server";
import { stripe } from "@/lib/stripe";

async function getAuthUser() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error("Ikke innlogget");
  return { supabase, user };
}

export async function createBookingAction(data: {
  listingId: string;
  checkIn: string;
  checkOut: string;
  totalPrice: number;
}): Promise<{ bookingId?: string; clientSecret?: string; error?: string }> {
  try {
    const { supabase, user } = await getAuthUser();

    // Get listing to find host
    const { data: listing } = await supabase
      .from("listings")
      .select("host_id, title")
      .eq("id", data.listingId)
      .single();

    if (!listing) return { error: "Annonse ikke funnet" };

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
      .select("id, user_id, payment_intent_id, payment_status")
      .eq("id", bookingId)
      .single();

    if (!booking) return { error: "Bestilling ikke funnet" };
    if (booking.user_id !== user.id) return { error: "Ikke tilgang" };

    // Refund if paid
    if (booking.payment_status === "paid" && booking.payment_intent_id) {
      await stripe.refunds.create({
        payment_intent: booking.payment_intent_id,
      });
    }

    await supabase
      .from("bookings")
      .update({ status: "cancelled", payment_status: "refunded" })
      .eq("id", bookingId);

    return {};
  } catch (err) {
    return { error: err instanceof Error ? err.message : "Noe gikk galt" };
  }
}
