import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { sendReviewReminderEmail } from "@/lib/email";
import { sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    // Find bookings where checkout was 1-2 days ago, no review exists, and reminder not sent
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split("T")[0];
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString().split("T")[0];

    const { data: bookings } = await supabase
      .from("bookings")
      .select("id, user_id, listing_id, review_reminder_sent")
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
      // Check if review already exists
      const { count } = await supabase
        .from("reviews")
        .select("id", { count: "exact", head: true })
        .eq("booking_id", booking.id);

      if (count && count > 0) continue;

      const { data: listing } = await supabase
        .from("listings")
        .select("title")
        .eq("id", booking.listing_id)
        .single();

      const { data: authData } = await supabase.auth.admin.getUserById(booking.user_id);
      const email = authData.user?.email;
      const name = authData.user?.user_metadata?.full_name || "Gjest";

      if (email) {
        const listingTitle = listing?.title || "plassen";
        await Promise.all([
          sendReviewReminderEmail(email, {
            guestName: name,
            listingTitle,
            bookingId: booking.id,
          }),
          sendPushToUser(
            booking.user_id,
            "Hvordan var oppholdet?",
            `Legg igjen en anmeldelse av ${listingTitle}.`,
            { bookingId: booking.id, type: "review_reminder" },
          ),
        ]);

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
