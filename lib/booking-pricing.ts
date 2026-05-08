// Delt server-side pris-helper for booking-flyter (create, request, offer, accept).
// Trukket ut av app/api/bookings/create/route.ts slik at samme logikk gjenbrukes
// uten å duplisere — særlig viktig for forhandling der prisen rekalkuleres pr. tilbud.

import { SERVICE_FEE_RATE } from "@/lib/config";
import {
  getNightlyPricesWithServiceClient,
  applyPriceBreakdown,
  applyLongerStayPricing,
  spotLongerStayTiers,
  type NightlyPrice,
  type LongerStayResult,
} from "@/lib/pricing";
import type { SpotMarker, ListingExtra, SelectedExtras } from "@/types";

export interface ComputeTotalArgs {
  listingId: string;
  listingPrice: number;
  spotMarkers: SpotMarker[] | null;
  listingExtras: ListingExtra[] | null;
  checkIn: string;
  checkOut: string;
  selectedSpotIds?: string[];
  selectedExtras?: SelectedExtras;
}

export interface ComputeTotalResult {
  total: number;
  breakdown: NightlyPrice[] | null;
  discount?: LongerStayResult | null;
}

export async function computeBookingTotal(args: ComputeTotalArgs): Promise<ComputeTotalResult> {
  const start = new Date(args.checkIn);
  const end = new Date(args.checkOut);
  // Inclusive begge endepunkter (parkering teller dager). 7. mai → 5. juni = 30 dager.
  const nights = Math.max(
    1,
    Math.round((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1,
  );

  const selectedSpots = (args.spotMarkers || []).filter(
    (s) => s.id && args.selectedSpotIds?.includes(s.id),
  );
  const hasPerSpotPricing = selectedSpots.length > 0 && selectedSpots.some((s) => s.price != null);

  let baseTotal: number;
  let breakdown: NightlyPrice[] | null = null;
  let discount: LongerStayResult | null = null;

  if (hasPerSpotPricing) {
    baseTotal = selectedSpots.reduce((sum, s) => {
      const base = s.price ?? args.listingPrice;
      const overrides = s.datePriceOverrides ?? {};
      let spotTotal = 0;
      const cursor = new Date(start);
      for (let i = 0; i < nights; i++) {
        const iso = cursor.toISOString().slice(0, 10);
        spotTotal += overrides[iso] ?? base;
        cursor.setUTCDate(cursor.getUTCDate() + 1);
      }
      return sum + spotTotal;
    }, 0);
  } else {
    breakdown = await getNightlyPricesWithServiceClient(
      {
        listingId: args.listingId,
        checkIn: args.checkIn,
        checkOut: args.checkOut,
        basePrice: args.listingPrice,
      },
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
    );
    const perDay = applyPriceBreakdown(breakdown);
    baseTotal = selectedSpots.length > 1 ? perDay * selectedSpots.length : perDay;
  }

  const targetSpot = args.selectedSpotIds?.length === 1
    ? selectedSpots.find((s) => s.id === args.selectedSpotIds![0])
    : selectedSpots[0] ?? (args.spotMarkers || [])[0];
  if (breakdown && targetSpot) {
    const tiers = spotLongerStayTiers(targetSpot);
    const hasAny =
      tiers.weeklyPrice > 0 ||
      tiers.monthlyPrice > 0 ||
      tiers.threeMonthPrice > 0 ||
      tiers.sixMonthPrice > 0 ||
      tiers.yearPrice > 0;
    if (hasAny) {
      discount = applyLongerStayPricing({
        breakdown,
        dailyPrice: tiers.dailyPrice,
        weeklyPrice: tiers.weeklyPrice,
        monthlyPrice: tiers.monthlyPrice,
        threeMonthPrice: tiers.threeMonthPrice,
        sixMonthPrice: tiers.sixMonthPrice,
        yearPrice: tiers.yearPrice,
      });
      baseTotal = discount.total;
    }
  }

  let extrasTotal = 0;
  for (const entry of args.selectedExtras?.listing || []) {
    const canonical = (args.listingExtras || []).find((e) => e.id === entry.id);
    if (!canonical) continue;
    extrasTotal += canonical.price * (canonical.perNight ? nights : 1) * entry.quantity;
  }
  for (const [spotId, entries] of Object.entries(args.selectedExtras?.spots || {})) {
    const spot = selectedSpots.find((s) => s.id === spotId);
    if (!spot) continue;
    for (const entry of entries) {
      const canonical = (spot.extras || []).find((e) => e.id === entry.id);
      if (!canonical) continue;
      extrasTotal += canonical.price * (canonical.perNight ? nights : 1) * entry.quantity;
    }
  }

  const subtotal = baseTotal + extrasTotal;
  const total = subtotal + Math.round(subtotal * SERVICE_FEE_RATE);
  return { total, breakdown, discount };
}
