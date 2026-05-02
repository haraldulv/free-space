import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { computeRefund, type CancelledBy } from "@/lib/cancellation";
import { sendCancellationEmail } from "@/lib/email";
import { sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
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

    const { bookingId, reason, preview } = await request.json() as {
      bookingId: string;
      reason?: string;
      preview?: boolean;
    };

    if (!bookingId) {
      return NextResponse.json({ error: "bookingId påkrevd" }, { status: 400 });
    }

    const { data: booking } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, listing_id, check_in, check_out, total_price, payment_intent_id, payment_status, transfer_status, stripe_transfer_id, status")
      .eq("id", bookingId)
      .single();

    if (!booking) {
      return NextResponse.json({ error: "Bestilling ikke funnet" }, { status: 404 });
    }
    if (booking.status === "cancelled") {
      return NextResponse.json({ error: "Allerede kansellert" }, { status: 400 });
    }

    const isGuest = booking.user_id === user.id;
    const isHost = booking.host_id === user.id;
    if (!isGuest && !isHost) {
      return NextResponse.json({ error: "Ikke tilgang" }, { status: 403 });
    }

    const cancelledBy: CancelledBy = isHost ? "host" : "guest";
    const result = computeRefund(booking.total_price, booking.check_in, cancelledBy);

    if (preview) {
      return NextResponse.json({
        refundAmount: result.refundAmount,
        policyLabel: result.policyLabel,
      });
    }

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

    // Varsler begge parter — den som kansellerte får bekreftelse, den
    // andre får varsel om at bookingen er borte. Tidligere sendte vi
    // INGEN e-post eller push fra denne ruten, så den andre parten
    // måtte oppdage det selv ved å åpne appen. Ikke greit.
    const [{ data: listing }, guestAuth, hostAuth, guestProfile, hostProfile] = await Promise.all([
      booking.listing_id
        ? supabase.from("listings").select("title").eq("id", booking.listing_id).single()
        : Promise.resolve({ data: null }),
      supabase.auth.admin.getUserById(booking.user_id),
      booking.host_id ? supabase.auth.admin.getUserById(booking.host_id) : Promise.resolve({ data: { user: null } }),
      supabase.from("profiles").select("full_name").eq("id", booking.user_id).single(),
      booking.host_id
        ? supabase.from("profiles").select("full_name").eq("id", booking.host_id).single()
        : Promise.resolve({ data: null }),
    ]);

    const listingTitle = listing?.title || "en plass";
    const guestEmail = guestAuth.data.user?.email;
    const hostEmail = hostAuth.data.user?.email;
    const guestName = guestProfile.data?.full_name || guestAuth.data.user?.user_metadata?.full_name || "Gjest";
    const hostName = hostProfile?.data?.full_name || hostAuth.data.user?.user_metadata?.full_name || "Utleier";

    const cancelSends: Promise<unknown>[] = [];

    // Push til gjest
    cancelSends.push(
      sendPushToUser(
        booking.user_id,
        cancelledBy === "guest" ? "Bestilling kansellert" : "Utleier har kansellert",
        cancelledBy === "guest"
          ? `Din kansellering av ${listingTitle} er bekreftet.${result.refundAmount > 0 ? ` Refusjon: ${result.refundAmount} kr.` : ""}`
          : `Utleier har kansellert ${listingTitle}.${result.refundAmount > 0 ? ` Refusjon: ${result.refundAmount} kr.` : ""}`,
        { bookingId: booking.id, type: "booking_cancelled" },
      ).catch((err) => console.error("[Push] cancel guest failed:", err)),
    );

    // Push til vert (hvis booking har en host som ikke er den som kansellerte selv)
    if (booking.host_id) {
      cancelSends.push(
        sendPushToUser(
          booking.host_id,
          cancelledBy === "host" ? "Bestilling kansellert" : "Gjest har kansellert",
          cancelledBy === "host"
            ? `Du har kansellert bookingen av ${listingTitle}.`
            : `${guestName} har kansellert bookingen av ${listingTitle}.`,
          { bookingId: booking.id, type: "booking_cancelled" },
        ).catch((err) => console.error("[Push] cancel host failed:", err)),
      );
    }

    // E-post til gjest
    if (guestEmail) {
      cancelSends.push(
        sendCancellationEmail(guestEmail, {
          name: guestName,
          listingTitle,
          checkIn: booking.check_in,
          checkOut: booking.check_out,
          refundAmount: result.refundAmount,
          cancelledBy,
        }).catch((err) => console.error("[Email] cancel guest failed:", err)),
      );
    }

    // E-post til vert
    if (hostEmail) {
      cancelSends.push(
        sendCancellationEmail(hostEmail, {
          name: hostName,
          listingTitle,
          checkIn: booking.check_in,
          checkOut: booking.check_out,
          refundAmount: result.refundAmount,
          cancelledBy,
        }).catch((err) => console.error("[Email] cancel host failed:", err)),
      );
    }

    await Promise.all(cancelSends);

    return NextResponse.json({
      refundAmount: result.refundAmount,
      policyLabel: result.policyLabel,
    });
  } catch (err) {
    console.error("Cancel booking error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 }
    );
  }
}
