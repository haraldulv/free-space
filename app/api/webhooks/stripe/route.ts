import { NextRequest, NextResponse } from "next/server";
import { stripe } from "@/lib/stripe";
import { createClient } from "@supabase/supabase-js";

// Use service role for webhook (no user auth context)
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(request: NextRequest) {
  const body = await request.text();
  const signature = request.headers.get("stripe-signature");

  if (!signature) {
    return NextResponse.json({ error: "No signature" }, { status: 400 });
  }

  let event;
  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return NextResponse.json({ error: "Invalid signature" }, { status: 400 });
  }

  if (event.type === "payment_intent.succeeded") {
    const paymentIntent = event.data.object;
    const bookingId = paymentIntent.metadata?.bookingId;
    const listingTitle = paymentIntent.metadata?.listingTitle || "en plass";

    if (bookingId) {
      // Update booking status
      await supabase
        .from("bookings")
        .update({
          status: "confirmed",
          payment_status: "paid",
        })
        .eq("id", bookingId);

      // Get booking to find host and guest
      const { data: booking } = await supabase
        .from("bookings")
        .select("user_id, host_id, check_in, check_out")
        .eq("id", bookingId)
        .single();

      if (booking) {
        // Notify host: new booking received
        if (booking.host_id) {
          await supabase.from("notifications").insert({
            user_id: booking.host_id,
            type: "booking_received",
            title: "Ny bestilling!",
            body: `Noen har bestilt ${listingTitle} (${booking.check_in} – ${booking.check_out})`,
            metadata: { bookingId },
          });
        }

        // Notify guest: booking confirmed
        await supabase.from("notifications").insert({
          user_id: booking.user_id,
          type: "booking_confirmed",
          title: "Bestilling bekreftet",
          body: `Din bestilling av ${listingTitle} er bekreftet og betalt.`,
          metadata: { bookingId },
        });
      }
    }
  }

  if (event.type === "payment_intent.payment_failed") {
    const paymentIntent = event.data.object;
    const bookingId = paymentIntent.metadata?.bookingId;

    if (bookingId) {
      await supabase
        .from("bookings")
        .update({
          payment_status: "failed",
        })
        .eq("id", bookingId);
    }
  }

  return NextResponse.json({ received: true });
}
