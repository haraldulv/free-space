import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { sendPushToUser } from "@/lib/push";

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

type SpotMarker = {
  id?: string;
  label?: string;
  checkinMessage?: string;
};

type SelectedExtraEntry = {
  id: string;
  name: string;
  message?: string;
};

type SelectedExtras = {
  listing?: SelectedExtraEntry[];
  spots?: Record<string, SelectedExtraEntry[]>;
};

function osloDateTimeString(date: Date): string {
  // Returns "YYYY-MM-DD HH:mm:ss" i Europe/Oslo-tid; string-sammenligning fungerer kronologisk.
  return date.toLocaleString("sv-SE", { timeZone: "Europe/Oslo" });
}

function composeMessage(
  listingMessage: string | null,
  spots: SpotMarker[],
  selectedSpotIds: string[] | null,
  selectedExtras: SelectedExtras | null,
): string | null {
  const parts: string[] = [];

  if (listingMessage && listingMessage.trim()) {
    parts.push(listingMessage.trim());
  }

  if (selectedSpotIds && selectedSpotIds.length > 0) {
    for (const spotId of selectedSpotIds) {
      const spot = spots.find((s) => s.id === spotId);
      const msg = spot?.checkinMessage?.trim();
      if (msg) {
        const label = spot?.label?.trim() || `Plass ${spotId.slice(0, 4)}`;
        parts.push(`${label}: ${msg}`);
      }
    }
  }

  // Extras-meldinger — både på listing-nivå og per-plass
  if (selectedExtras) {
    const allEntries = [
      ...(selectedExtras.listing ?? []),
      ...Object.values(selectedExtras.spots ?? {}).flat(),
    ];
    for (const entry of allEntries) {
      const msg = entry.message?.trim();
      if (msg) {
        parts.push(`${entry.name}: ${msg}`);
      }
    }
  }

  if (parts.length === 0) return null;
  return parts.join("\n\n");
}

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const osloNow = osloDateTimeString(new Date());
    const osloToday = osloNow.slice(0, 10);

    const { data: bookings, error: bookingsError } = await supabase
      .from("bookings")
      .select("id, user_id, host_id, listing_id, check_in, selected_spot_ids, selected_extras")
      .eq("status", "confirmed")
      .eq("payment_status", "paid")
      .is("checkin_message_sent_at", null)
      .lte("check_in", osloToday);

    if (bookingsError) {
      console.error("[checkin-messages] bookings query error:", bookingsError.message);
      return NextResponse.json({ error: bookingsError.message }, { status: 500 });
    }

    if (!bookings || bookings.length === 0) {
      return NextResponse.json({ sent: 0 });
    }

    let sent = 0;
    let skipped = 0;

    for (const booking of bookings) {
      const { data: listing } = await supabase
        .from("listings")
        .select("title, check_in_time, checkin_message, spot_markers, host_id")
        .eq("id", booking.listing_id)
        .single();

      if (!listing) {
        skipped++;
        continue;
      }

      const checkInTime = (listing.check_in_time as string) || "15:00";
      const scheduledOslo = `${booking.check_in} ${checkInTime}:00`;
      if (osloNow < scheduledOslo) {
        skipped++;
        continue;
      }

      const spots = (listing.spot_markers as SpotMarker[]) || [];
      const content = composeMessage(
        (listing.checkin_message as string) || null,
        spots,
        (booking.selected_spot_ids as string[] | null) || null,
        (booking.selected_extras as SelectedExtras | null) || null,
      );

      if (!content) {
        // Ingen melding å sende — stemple så vi ikke vurderer bookingen igjen.
        await supabase
          .from("bookings")
          .update({ checkin_message_sent_at: new Date().toISOString() })
          .eq("id", booking.id);
        skipped++;
        continue;
      }

      // Ensure conversation exists (unique on listing_id, guest_id).
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
        console.error("[checkin-messages] no conversation for booking", booking.id);
        skipped++;
        continue;
      }

      const { error: msgError } = await supabase.from("messages").insert({
        conversation_id: convo.id,
        sender_id: booking.host_id,
        content,
      });

      if (msgError) {
        console.error("[checkin-messages] message insert error:", msgError.message);
        skipped++;
        continue;
      }

      await supabase.from("notifications").insert({
        user_id: booking.user_id,
        type: "new_message",
        title: "Melding fra utleier",
        body: content.slice(0, 120),
        metadata: { conversationId: convo.id },
      });

      await sendPushToUser(
        booking.user_id,
        "Melding fra utleier",
        content.slice(0, 120),
      );

      await supabase
        .from("bookings")
        .update({ checkin_message_sent_at: new Date().toISOString() })
        .eq("id", booking.id);

      sent++;
    }

    return NextResponse.json({ sent, skipped, checked: bookings.length });
  } catch (err) {
    console.error("[checkin-messages] error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
