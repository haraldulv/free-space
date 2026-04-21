import { NextRequest, NextResponse } from "next/server";
import { stripe } from "@/lib/stripe";
import { createClient } from "@supabase/supabase-js";
import {
  sendBookingConfirmation,
  sendBookingNotificationToHost,
  sendBookingRequestToHost,
  sendBookingRequestPendingToGuest,
} from "@/lib/email";
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

  // Non-instant flyt: PI er autorisert (capture_method=manual). Vi setter
  // booking.status='requested' og varsler host. Capture skjer først ved
  // host-godkjenning (approveBookingAction).
  if (event.type === "payment_intent.amount_capturable_updated") {
    const paymentIntent = event.data.object;
    const bookingId = paymentIntent.metadata?.bookingId;
    const listingTitle = paymentIntent.metadata?.listingTitle || "en plass";

    if (bookingId) {
      // Bare oppdater hvis status fortsatt er 'pending' (idempotent ved retry).
      const { data: existing } = await supabase
        .from("bookings")
        .select("status, user_id, host_id, listing_id, check_in, check_out, total_price, approval_deadline, selected_extras")
        .eq("id", bookingId)
        .single();

      if (existing && existing.status === "pending") {
        await supabase
          .from("bookings")
          .update({ status: "requested" })
          .eq("id", bookingId);

        const [guestRes, hostRes, listingRes] = await Promise.all([
          supabase.auth.admin.getUserById(existing.user_id),
          existing.host_id ? supabase.auth.admin.getUserById(existing.host_id) : null,
          existing.listing_id ? supabase.from("listings").select("images").eq("id", existing.listing_id).single() : null,
        ]);
        const guestEmail = guestRes.data.user?.email;
        const guestName = guestRes.data.user?.user_metadata?.full_name || "Gjest";
        const hostEmail = hostRes?.data.user?.email;
        const hostName = hostRes?.data.user?.user_metadata?.full_name || "Utleier";
        const listingImage = listingRes?.data?.images?.[0] ?? null;

        const emailSends: Promise<unknown>[] = [];

        // Push til host: ny forespørsel
        if (existing.host_id) {
          emailSends.push(
            sendPushToUser(
              existing.host_id,
              "Ny booking-forespørsel",
              `${guestName} ønsker å booke ${listingTitle}. Du har 24 timer på å svare.`,
              { bookingId, type: "booking_request" },
            ).catch((err) => console.error("[Push] Host request notify failed:", err)),
          );
        }

        // E-post til host + bekreftelse til gjest
        if (hostEmail) {
          emailSends.push(
            sendBookingRequestToHost(hostEmail, {
              hostName,
              guestName,
              listingTitle,
              listingId: existing.listing_id,
              listingImage,
              checkIn: existing.check_in,
              checkOut: existing.check_out,
              totalPrice: existing.total_price,
              approvalDeadline: existing.approval_deadline,
              selectedExtras: existing.selected_extras,
            }).catch((err) => console.error("[Email] Host request failed:", err)),
          );
        }
        if (guestEmail) {
          emailSends.push(
            sendBookingRequestPendingToGuest(guestEmail, {
              guestName,
              listingTitle,
              listingId: existing.listing_id,
              listingImage,
              checkIn: existing.check_in,
              checkOut: existing.check_out,
              totalPrice: existing.total_price,
              selectedExtras: existing.selected_extras,
            }).catch((err) => console.error("[Email] Guest pending failed:", err)),
          );
        }
        await Promise.all(emailSends);
      }
    }
  }

  if (event.type === "payment_intent.succeeded") {
    const paymentIntent = event.data.object;
    const bookingId = paymentIntent.metadata?.bookingId;
    const listingTitle = paymentIntent.metadata?.listingTitle || "en plass";

    if (bookingId) {
      // Bare bekreft hvis ikke allerede cancelled — unngår race med decline-action.
      await supabase
        .from("bookings")
        .update({
          status: "confirmed",
          payment_status: "paid",
        })
        .eq("id", bookingId)
        .neq("status", "cancelled");

      // Get booking + profiles for notifications and emails
      const { data: booking } = await supabase
        .from("bookings")
        .select("user_id, host_id, listing_id, check_in, check_out, total_price, selected_extras")
        .eq("id", bookingId)
        .single();

      if (booking) {
        const [guestRes, hostRes, listingRes] = await Promise.all([
          supabase.auth.admin.getUserById(booking.user_id),
          booking.host_id ? supabase.from("profiles").select("full_name").eq("id", booking.host_id).single() : null,
          booking.listing_id ? supabase.from("listings").select("images").eq("id", booking.listing_id).single() : null,
        ]);
        const listingImage = listingRes?.data?.images?.[0] ?? null;
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

        // Send push notifications (await så serverless ikke termineres før APNs fullfører)
        const pushSends: Promise<unknown>[] = [];
        if (booking.host_id) {
          pushSends.push(
            sendPushToUser(
              booking.host_id,
              "Ny bestilling!",
              `${guestName} har booket ${listingTitle}`,
              { bookingId, type: "booking_new" },
            )
              .then(() => console.log(`[Push] Host notified: ${booking.host_id}`))
              .catch((err) => console.error(`[Push] Failed to notify host ${booking.host_id}:`, err)),
          );
        }
        pushSends.push(
          sendPushToUser(
            booking.user_id,
            "Booking bekreftet",
            `Din booking av ${listingTitle} er bekreftet`,
            { bookingId, type: "booking_confirmed" },
          )
            .then(() => console.log(`[Push] Guest notified: ${booking.user_id}`))
            .catch((err) => console.error(`[Push] Failed to notify guest ${booking.user_id}:`, err)),
        );
        await Promise.all(pushSends);

        // Send branded emails (await så serverless ikke termineres før sendingen er ferdig)
        const emailSends: Promise<unknown>[] = [];
        if (guestEmail) {
          console.log(`[Email] Sending booking confirmation to ${guestEmail}`);
          emailSends.push(
            sendBookingConfirmation(guestEmail, {
              guestName,
              listingTitle,
              listingId: booking.listing_id,
              listingImage,
              checkIn: booking.check_in,
              checkOut: booking.check_out,
              totalPrice: booking.total_price,
              bookingId,
              selectedExtras: booking.selected_extras,
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
              listingId: booking.listing_id,
              listingImage,
              checkIn: booking.check_in,
              checkOut: booking.check_out,
              totalPrice: booking.total_price,
              selectedExtras: booking.selected_extras,
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
