import { NextRequest, NextResponse } from "next/server";
import { stripe } from "@/lib/stripe";
import { createClient } from "@supabase/supabase-js";
import { sendBookingConfirmation, sendBookingNotificationToHost } from "@/lib/email";
import { sendPushToUser } from "@/lib/push";

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

  // Stripe sender platform-events (payment_intent.*) og Connect-events (account.updated)
  // til samme URL men med forskjellige signing secrets — ett per endpoint i Dashboard.
  // Prøv begge secrets og aksepter requesten hvis én matcher.
  const secrets = [
    process.env.STRIPE_WEBHOOK_SECRET,
    process.env.STRIPE_CONNECT_WEBHOOK_SECRET,
  ].filter((s): s is string => Boolean(s));

  let event;
  let lastError: unknown;
  for (const secret of secrets) {
    try {
      event = stripe.webhooks.constructEvent(body, signature, secret);
      break;
    } catch (err) {
      lastError = err;
    }
  }

  if (!event) {
    console.error("Webhook signature verification failed:", lastError);
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

      // Get booking + profiles for notifications and emails
      const { data: booking } = await supabase
        .from("bookings")
        .select("user_id, host_id, check_in, check_out, total_price")
        .eq("id", bookingId)
        .single();

      if (booking) {
        const [guestRes, hostRes] = await Promise.all([
          supabase.auth.admin.getUserById(booking.user_id),
          booking.host_id ? supabase.from("profiles").select("full_name").eq("id", booking.host_id).single() : null,
        ]);
        const guestEmail = guestRes.data.user?.email;
        const guestName = guestRes.data.user?.user_metadata?.full_name || "Gjest";
        const hostName = hostRes?.data?.full_name || "Utleier";
        const hostEmail = booking.host_id ? (await supabase.auth.admin.getUserById(booking.host_id)).data.user?.email : null;

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

        // Send push notifications
        if (booking.host_id) {
          sendPushToUser(booking.host_id, "Ny bestilling!", `${guestName} har booket ${listingTitle}`);
        }
        sendPushToUser(booking.user_id, "Booking bekreftet", `Din booking av ${listingTitle} er bekreftet`);

        // Send branded emails (await så serverless ikke termineres før sendingen er ferdig)
        const emailSends: Promise<unknown>[] = [];
        if (guestEmail) {
          console.log(`[Email] Sending booking confirmation to ${guestEmail}`);
          emailSends.push(
            sendBookingConfirmation(guestEmail, {
              guestName,
              listingTitle,
              checkIn: booking.check_in,
              checkOut: booking.check_out,
              totalPrice: booking.total_price,
              bookingId,
            })
              .then(() => console.log(`[Email] Booking confirmation sent to ${guestEmail}`))
              .catch((err) => console.error(`[Email] Failed to send to ${guestEmail}:`, err)),
          );
        } else {
          console.warn(`[Email] No guest email for booking ${bookingId}`);
        }
        if (hostEmail) {
          console.log(`[Email] Sending host notification to ${hostEmail}`);
          emailSends.push(
            sendBookingNotificationToHost(hostEmail, {
              hostName,
              guestName,
              listingTitle,
              checkIn: booking.check_in,
              checkOut: booking.check_out,
              totalPrice: booking.total_price,
            })
              .then(() => console.log(`[Email] Host notification sent to ${hostEmail}`))
              .catch((err) => console.error(`[Email] Failed to send to ${hostEmail}:`, err)),
          );
        }
        await Promise.all(emailSends);
      }
    }
  }

  if (event.type === "account.updated") {
    const account = event.data.object;
    if (account.charges_enabled) {
      await supabase
        .from("profiles")
        .update({ stripe_onboarding_complete: true })
        .eq("stripe_account_id", account.id);
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
