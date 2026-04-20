import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { createTransfer } from "@/lib/stripe";
import { SERVICE_FEE_RATE } from "@/lib/config";
import { sendPayoutEmail } from "@/lib/email";
import { sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

export async function GET(request: NextRequest) {
  // Verify cron secret
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    // Find bookings ready for payout: confirmed, paid, pending transfer, check-in was 24h+ ago
    const cutoff = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().split("T")[0];

    const { data: bookings, error: queryError } = await supabase
      .from("bookings")
      .select("id, total_price, host_id, listing_id")
      .eq("status", "confirmed")
      .eq("payment_status", "paid")
      .eq("transfer_status", "pending")
      .lte("check_in", cutoff);

    if (queryError) {
      console.error("Payout query error:", queryError);
      return NextResponse.json({ error: queryError.message }, { status: 500 });
    }

    if (!bookings || bookings.length === 0) {
      return NextResponse.json({ processed: 0 });
    }

    let processed = 0;
    const errors: string[] = [];

    for (const booking of bookings) {
      try {
        // Get host's Stripe account
        const { data: profile } = await supabase
          .from("profiles")
          .select("stripe_account_id, stripe_onboarding_complete")
          .eq("id", booking.host_id)
          .single();

        if (!profile?.stripe_account_id || !profile.stripe_onboarding_complete) {
          errors.push(`Booking ${booking.id}: host has no Stripe account`);
          continue;
        }

        // Calculate host payout (total minus platform fee), in øre
        const hostAmount = Math.round(booking.total_price * (1 - SERVICE_FEE_RATE) * 100);

        // Get listing title for notification
        const { data: listing } = await supabase
          .from("listings")
          .select("title")
          .eq("id", booking.listing_id)
          .single();

        // Create transfer
        const transfer = await createTransfer(
          hostAmount,
          profile.stripe_account_id,
          { bookingId: booking.id, listingId: booking.listing_id },
        );

        // Update booking
        await supabase
          .from("bookings")
          .update({
            transfer_status: "transferred",
            stripe_transfer_id: transfer.id,
          })
          .eq("id", booking.id);

        const hostAmountNok = Math.round(booking.total_price * (1 - SERVICE_FEE_RATE));

        // Notify host
        await supabase.from("notifications").insert({
          user_id: booking.host_id,
          type: "payout_sent",
          title: "Utbetaling sendt!",
          body: `${hostAmountNok} kr er overført til din konto for ${listing?.title || "en bestilling"}.`,
          metadata: { bookingId: booking.id },
        });

        // Send payout email + push
        const { data: hostAuth } = await supabase.auth.admin.getUserById(booking.host_id);
        const { data: hostProfile } = await supabase.from("profiles").select("full_name").eq("id", booking.host_id).single();
        const listingTitle = listing?.title || "en plass";
        const payoutSends: Promise<unknown>[] = [
          sendPushToUser(
            booking.host_id,
            "Utbetaling sendt!",
            `${hostAmountNok} kr er overført til din konto for ${listingTitle}.`,
            { bookingId: booking.id, type: "payout_sent" },
          ).catch((err) => console.error("[Push] payout failed:", err)),
        ];
        if (hostAuth.user?.email) {
          payoutSends.push(
            sendPayoutEmail(hostAuth.user.email, {
              hostName: hostProfile?.full_name || "Utleier",
              amount: hostAmountNok,
              listingTitle,
            }).catch((err) => console.error("[Email] payout failed:", err)),
          );
        }
        await Promise.all(payoutSends);

        processed++;
      } catch (err) {
        const msg = err instanceof Error ? err.message : "Unknown error";
        errors.push(`Booking ${booking.id}: ${msg}`);
        console.error(`Payout error for booking ${booking.id}:`, err);
      }
    }

    return NextResponse.json({ processed, total: bookings.length, errors });
  } catch (err) {
    console.error("Process payouts error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
