import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { sendReviewReminderEmail } from "@/lib/email";
import { sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

/**
 * Sender review-påminnelse 1-2 dager etter utsjekk til BÅDE gjest og host
 * som ennå ikke har skrevet sin anmeldelse. Kjøres daglig.
 */
export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split("T")[0];
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];

    const { data: bookings } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, listing_id, review_reminder_sent")
      .eq("status", "confirmed")
      .eq("payment_status", "paid")
      .lte("check_out", oneDayAgo)
      .gte("check_out", twoDaysAgo)
      .or("review_reminder_sent.is.null,review_reminder_sent.eq.false");

    if (!bookings || bookings.length === 0) {
      return NextResponse.json({ sent: 0 });
    }

    let sent = 0;

    for (const booking of bookings) {
      const { data: existingReviews } = await supabase
        .from("reviews")
        .select("reviewer_role")
        .eq("booking_id", booking.id);

      const guestHasReviewed = (existingReviews || []).some((r) => r.reviewer_role === "guest");
      const hostHasReviewed = (existingReviews || []).some((r) => r.reviewer_role === "host");

      const { data: listing } = await supabase
        .from("listings")
        .select("title")
        .eq("id", booking.listing_id)
        .single();
      const listingTitle = listing?.title || "plassen";

      const sends: Promise<unknown>[] = [];

      if (!guestHasReviewed) {
        const { data: guestAuth } = await supabase.auth.admin.getUserById(booking.user_id);
        const email = guestAuth.user?.email;
        const name = guestAuth.user?.user_metadata?.full_name || "Gjest";
        if (email) {
          sends.push(
            sendReviewReminderEmail(email, {
              guestName: name,
              listingTitle,
              bookingId: booking.id,
            }),
          );
        }
        sends.push(
          sendPushToUser(
            booking.user_id,
            "Hvordan var oppholdet?",
            `Legg igjen en anmeldelse av ${listingTitle}.`,
            { bookingId: booking.id, type: "review_reminder" },
          ),
        );
      }

      if (!hostHasReviewed && booking.host_id) {
        const { data: hostAuth } = await supabase.auth.admin.getUserById(booking.host_id);
        const email = hostAuth.user?.email;
        const name = hostAuth.user?.user_metadata?.full_name || "Utleier";
        if (email) {
          sends.push(
            sendReviewReminderEmail(email, {
              guestName: name,
              listingTitle: `gjesten av ${listingTitle}`,
              bookingId: booking.id,
            }),
          );
        }
        sends.push(
          sendPushToUser(
            booking.host_id,
            "Anmeld gjesten",
            `Hvordan var gjesten på ${listingTitle}?`,
            { bookingId: booking.id, type: "review_reminder" },
          ),
        );
      }

      if (sends.length > 0) {
        await Promise.all(sends);
        await supabase
          .from("bookings")
          .update({ review_reminder_sent: true })
          .eq("id", booking.id);
        sent++;
      }
    }

    return NextResponse.json({ sent, checked: bookings.length });
  } catch (err) {
    console.error("Review reminder error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
