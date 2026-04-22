import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

function osloDateTimeString(date: Date): string {
  return date.toLocaleString("sv-SE", { timeZone: "Europe/Oslo" });
}

/**
 * Trekker N timer fra en "YYYY-MM-DD HH:mm:ss"-streng (Oslo-tid).
 * Returnerer en streng i samme format. Brukes for å regne ut når checkout-meldingen
 * skal sendes (checkout-tid minus send_hours_before).
 */
function subtractHours(osloDateTime: string, hours: number): string {
  // osloDateTime er på form "YYYY-MM-DD HH:mm:ss" i Europe/Oslo-tid.
  // Vi parser det som om det var UTC slik at subtraksjon + re-format gir samme wall-clock,
  // så sammenligninger med osloNow (også wall-clock) fungerer.
  const asUtc = new Date(osloDateTime.replace(" ", "T") + "Z");
  asUtc.setUTCHours(asUtc.getUTCHours() - hours);
  const y = asUtc.getUTCFullYear();
  const m = String(asUtc.getUTCMonth() + 1).padStart(2, "0");
  const d = String(asUtc.getUTCDate()).padStart(2, "0");
  const hh = String(asUtc.getUTCHours()).padStart(2, "0");
  const mm = String(asUtc.getUTCMinutes()).padStart(2, "0");
  const ss = String(asUtc.getUTCSeconds()).padStart(2, "0");
  return `${y}-${m}-${d} ${hh}:${mm}:${ss}`;
}

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const osloNow = osloDateTimeString(new Date());
    const osloToday = osloNow.slice(0, 10);

    // Se på bookinger med check_out i dag eller tidligere (opptil 2 dager tilbake for
    // å fange opp tilfeller der cronjobben har vært nede).
    const osloRangeStart = new Date();
    osloRangeStart.setUTCDate(osloRangeStart.getUTCDate() - 2);
    const osloRangeStartDate = osloRangeStart.toISOString().slice(0, 10);

    // Fremtidige check_out opptil 2 dager frem i tid — da treffer send_hours_before=48t også.
    const osloRangeEnd = new Date();
    osloRangeEnd.setUTCDate(osloRangeEnd.getUTCDate() + 2);
    const osloRangeEndDate = osloRangeEnd.toISOString().slice(0, 10);

    const { data: bookings, error: bookingsError } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, listing_id, check_out, check_out_time")
      .eq("status", "confirmed")
      .eq("payment_status", "paid")
      .is("checkout_message_sent_at", null)
      .gte("check_out", osloRangeStartDate)
      .lte("check_out", osloRangeEndDate);

    if (bookingsError) {
      console.error("[checkout-messages] bookings query error:", bookingsError.message);
      return NextResponse.json({ error: bookingsError.message }, { status: 500 });
    }

    if (!bookings || bookings.length === 0) {
      return NextResponse.json({ sent: 0, checked: 0 });
    }

    let sent = 0;
    let skipped = 0;

    for (const booking of bookings) {
      const { data: listing } = await supabase
        .from("listings")
        .select("title, check_out_time, checkout_message, checkout_message_send_hours_before")
        .eq("id", booking.listing_id)
        .single();

      if (!listing) {
        skipped++;
        continue;
      }

      const checkoutMessage = (listing.checkout_message as string | null)?.trim();
      if (!checkoutMessage) {
        // Host har ikke aktivert utsjekkmelding — marker som sendt så vi slutter å evaluere.
        await supabase
          .from("bookings")
          .update({ checkout_message_sent_at: new Date().toISOString() })
          .eq("id", booking.id);
        skipped++;
        continue;
      }

      const checkOutTime = (booking.check_out_time as string) || (listing.check_out_time as string) || "11:00";
      const hoursBefore = (listing.checkout_message_send_hours_before as number) ?? 2;
      const checkoutScheduledOslo = `${booking.check_out} ${checkOutTime}:00`;
      const sendAtOslo = subtractHours(checkoutScheduledOslo, hoursBefore);

      if (osloNow < sendAtOslo) {
        skipped++;
        continue;
      }

      // Finn/lag conversation for å sende meldingen
      await supabase
        .from("conversations")
        .upsert(
          {
            listing_id: booking.listing_id,
            guest_id: booking.user_id,
            host_id: booking.host_id,
            booking_id: booking.id,
          },
          { onConflict: "listing_id,guest_id", ignoreDuplicates: true },
        );

      const { data: convo } = await supabase
        .from("conversations")
        .select("id")
        .eq("listing_id", booking.listing_id)
        .eq("guest_id", booking.user_id)
        .maybeSingle();

      if (!convo) {
        console.error("[checkout-messages] no conversation for booking", booking.id);
        skipped++;
        continue;
      }

      const { error: msgError } = await supabase.from("messages").insert({
        conversation_id: convo.id,
        sender_id: booking.host_id,
        content: checkoutMessage,
      });

      if (msgError) {
        console.error("[checkout-messages] message insert error:", msgError.message);
        skipped++;
        continue;
      }

      await supabase.from("notifications").insert({
        user_id: booking.user_id,
        type: "new_message",
        title: "Melding fra utleier",
        body: checkoutMessage.slice(0, 120),
        metadata: { conversationId: convo.id },
      });

      await sendPushToUser(
        booking.user_id,
        "Melding fra utleier",
        checkoutMessage.slice(0, 120),
      );

      await supabase
        .from("bookings")
        .update({ checkout_message_sent_at: new Date().toISOString() })
        .eq("id", booking.id);

      sent++;
    }

    return NextResponse.json({ sent, skipped, checked: bookings.length, osloNow, osloToday });
  } catch (err) {
    console.error("[checkout-messages] error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
