import { createClient } from "./server";
import { SERVICE_FEE_RATE } from "@/lib/config";

export type ListingStats = {
  occupancyPct: number;        // belegg siste N dager (0-100)
  revenue: number;             // host-andel siste N dager (kr)
  upcomingBookings: number;    // antall bekreftede + requested fra i dag
  nextCheckIn: string | null;  // dato for nærmeste kommende booking
};

export type SpotStats = ListingStats & {
  spotId: string;
  label: string;
};

const HOST_SHARE = 1 - SERVICE_FEE_RATE;

function dateNDaysAgoIso(n: number): string {
  return new Date(Date.now() - n * 24 * 60 * 60 * 1000).toISOString().split("T")[0];
}

function todayIso(): string {
  return new Date().toISOString().split("T")[0];
}

function nightsBetween(checkIn: string, checkOut: string): number {
  const ms = new Date(checkOut).getTime() - new Date(checkIn).getTime();
  return Math.max(1, Math.round(ms / (1000 * 60 * 60 * 24)));
}

/**
 * Stats for en hel annonse (alle plasser samlet) over siste N dager.
 * Belegg = (utleide dager / (kapasitet × N)). Inntekt = host-andel av confirmed.
 */
export async function getListingStats(
  listingId: string,
  days: number = 30,
): Promise<ListingStats> {
  const supabase = await createClient();
  const fromDate = dateNDaysAgoIso(days);
  const today = todayIso();

  const { data: listing } = await supabase
    .from("listings")
    .select("spots")
    .eq("id", listingId)
    .single();
  const capacity = (listing?.spots as number) || 1;

  // Bookinger som overlapper de siste N dagene (for belegg + inntekt)
  const { data: pastWindow } = await supabase
    .from("bookings")
    .select("check_in, check_out, total_price, selected_spot_ids, status")
    .eq("listing_id", listingId)
    .in("status", ["confirmed"])
    .lt("check_in", today)
    .gte("check_out", fromDate);

  let occupiedNights = 0;
  let revenue = 0;
  for (const b of pastWindow || []) {
    const ci = (b.check_in as string) > fromDate ? (b.check_in as string) : fromDate;
    const co = (b.check_out as string) < today ? (b.check_out as string) : today;
    const overlapNights = Math.max(0, nightsBetween(ci, co));
    const occupies = (b.selected_spot_ids as string[] | null)?.length || 1;
    occupiedNights += overlapNights * occupies;
    revenue += Math.round((b.total_price as number) * HOST_SHARE);
  }

  const occupancyPct = Math.min(100, Math.round((occupiedNights / (capacity * days)) * 100));

  // Kommende bookinger (confirmed + requested fra i dag)
  const { data: upcoming } = await supabase
    .from("bookings")
    .select("check_in")
    .eq("listing_id", listingId)
    .in("status", ["confirmed", "requested"])
    .gte("check_in", today)
    .order("check_in", { ascending: true });

  return {
    occupancyPct,
    revenue,
    upcomingBookings: upcoming?.length || 0,
    nextCheckIn: (upcoming?.[0]?.check_in as string) || null,
  };
}

/**
 * Stats per plass innenfor en annonse, basert på selected_spot_ids på bookings.
 * Bookinger uten selected_spot_ids tilskrives ikke en spesifikk plass.
 */
export async function getSpotStatsForListing(
  listingId: string,
  spots: { id: string; label?: string }[],
  days: number = 30,
): Promise<SpotStats[]> {
  const supabase = await createClient();
  const fromDate = dateNDaysAgoIso(days);
  const today = todayIso();

  const { data: pastWindow } = await supabase
    .from("bookings")
    .select("check_in, check_out, total_price, selected_spot_ids")
    .eq("listing_id", listingId)
    .eq("status", "confirmed")
    .lt("check_in", today)
    .gte("check_out", fromDate);

  const { data: upcoming } = await supabase
    .from("bookings")
    .select("check_in, selected_spot_ids")
    .eq("listing_id", listingId)
    .in("status", ["confirmed", "requested"])
    .gte("check_in", today)
    .order("check_in", { ascending: true });

  return spots.map((spot) => {
    let occupiedNights = 0;
    let revenue = 0;

    for (const b of pastWindow || []) {
      const ids = (b.selected_spot_ids as string[] | null) || [];
      if (!ids.includes(spot.id)) continue;
      const ci = (b.check_in as string) > fromDate ? (b.check_in as string) : fromDate;
      const co = (b.check_out as string) < today ? (b.check_out as string) : today;
      occupiedNights += Math.max(0, nightsBetween(ci, co));
      // Fordel pris likt mellom valgte plasser i bookingen
      revenue += Math.round((b.total_price as number) * HOST_SHARE / ids.length);
    }

    const upcomingForSpot = (upcoming || []).filter((b) =>
      ((b.selected_spot_ids as string[] | null) || []).includes(spot.id),
    );

    return {
      spotId: spot.id,
      label: spot.label || spot.id,
      occupancyPct: Math.min(100, Math.round((occupiedNights / days) * 100)),
      revenue,
      upcomingBookings: upcomingForSpot.length,
      nextCheckIn: (upcomingForSpot[0]?.check_in as string) || null,
    };
  });
}
