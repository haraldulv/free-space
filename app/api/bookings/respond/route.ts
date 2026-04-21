import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { sendPushToUser } from "@/lib/push";
import {
  sendBookingApprovedToGuest,
  sendBookingDeclinedToGuest,
} from "@/lib/email";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

export async function POST(request: NextRequest) {
  try {
    const authHeader = request.headers.get("authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return NextResponse.json({ error: "Ikke innlogget" }, { status: 401 });
    }

    const token = authHeader.slice(7);
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return NextResponse.json({ error: "Ugyldig token" }, { status: 401 });
    }

    const { bookingId, action } = await request.json() as {
      bookingId: string;
      action: "approve" | "decline";
    };

    if (!bookingId || (action !== "approve" && action !== "decline")) {
      return NextResponse.json({ error: "bookingId og action påkrevd" }, { status: 400 });
    }

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, host_id, status, payment_intent_id, approval_deadline, user_id, listing_id, check_in, check_out, total_price, selected_extras")
      .eq("id", bookingId)
      .single();

    if (!booking) {
      return NextResponse.json({ error: "Bestilling ikke funnet" }, { status: 404 });
    }
    if (booking.host_id !== user.id) {
      return NextResponse.json({ error: "Ikke tilgang" }, { status: 403 });
    }
    if (booking.status !== "requested") {
      return NextResponse.json({ error: "Bookingen kan ikke besvares" }, { status: 400 });
    }

    const [{ data: listing }, guestAuth] = await Promise.all([
      supabase.from("listings").select("title, images").eq("id", booking.listing_id).single(),
      supabase.auth.admin.getUserById(booking.user_id),
    ]);
    const guestEmail = guestAuth.data.user?.email;
    const guestName = guestAuth.data.user?.user_metadata?.full_name || "Gjest";
    const listingTitle = listing?.title || "en plass";

    if (action === "approve") {
      if (booking.approval_deadline && new Date(booking.approval_deadline) < new Date()) {
        return NextResponse.json({ error: "Tidsfristen for å godkjenne har gått ut" }, { status: 400 });
      }
      if (!booking.payment_intent_id) {
        return NextResponse.json({ error: "Mangler betalingsinformasjon" }, { status: 400 });
      }

      await stripe.paymentIntents.capture(booking.payment_intent_id);

      await supabase
        .from("bookings")
        .update({
          status: "confirmed",
          payment_status: "paid",
          host_responded_at: new Date().toISOString(),
        })
        .eq("id", bookingId);

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
            selectedExtras: booking.selected_extras,
          }).catch((err) => console.error("[Email] approve failed:", err)),
        );
      }
      await Promise.all(approveSends);

      return NextResponse.json({ status: "confirmed" });
    }

    // action === "decline"
    if (booking.payment_intent_id) {
      try {
        await stripe.paymentIntents.cancel(booking.payment_intent_id);
      } catch (err) {
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
        cancellation_reason: "host_declined",
        host_responded_at: new Date().toISOString(),
      })
      .eq("id", bookingId);

    const declineSends: Promise<unknown>[] = [
      sendPushToUser(
        booking.user_id,
        "Forespørselen ble avvist",
        `Utleier kunne ikke ta imot ${listingTitle}. Beløpet er frigjort.`,
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
          autoDeclined: false,
        }).catch((err) => console.error("[Email] decline failed:", err)),
      );
    }
    await Promise.all(declineSends);

    return NextResponse.json({ status: "cancelled" });
  } catch (err) {
    console.error("POST /api/bookings/respond error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
