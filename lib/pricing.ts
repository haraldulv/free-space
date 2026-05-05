import { createClient as createServerClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";

export type PriceSource = "base" | "weekend" | "season" | "override";

export interface NightlyPrice {
  /** ISO dato "YYYY-MM-DD" (natten/døgnet som starter denne datoen). */
  date: string;
  price: number;
  source: PriceSource;
}

export interface PricingRule {
  id: string;
  listingId: string;
  kind: "weekend" | "season";
  dayMask: number | null;        // bitmask: bit 0 = Mandag, bit 6 = Søndag
  startDate: string | null;      // for 'season'
  endDate: string | null;        // for 'season', inclusive
  price: number;
  /** Hvilken plass (SpotMarker.id) regelen gjelder. NULL = listing-wide. */
  spotId: string | null;
  /** Utleier-valgt farge-indeks (0-4 i palett). NULL = derives fra rule.id-hash. */
  colorIndex: number | null;
}

export interface PricingOverride {
  listingId: string;
  date: string;
  price: number;
  /** Hvilken plass (SpotMarker.id) overstyringen gjelder. NULL = listing-wide. */
  spotId: string | null;
}

/** Default helg-maske: fredag (bit 4), lørdag (bit 5), søndag (bit 6). */
export const WEEKEND_DAY_MASK = (1 << 4) | (1 << 5) | (1 << 6);

/** ISO weekday 1..7 (Mandag..Søndag) → bit-index 0..6. */
function weekdayBit(date: Date): number {
  // JS Date.getDay(): Søn=0, Man=1, ..., Lør=6
  const d = date.getDay();
  return d === 0 ? 6 : d - 1;
}

function formatDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const dd = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${dd}`;
}

function parseDate(iso: string): Date {
  return new Date(iso + "T00:00:00");
}

/**
 * Server-autoritativ prising: gitt en dato og satt av regler/overrides/base,
 * returner pris + kilde. Presedens: override > sesong > helg > base.
 *
 * Sesong-bånd støtter:
 *   - dato-range (startDate–endDate, inklusiv begge ender)
 *   - valgfri day_mask (NULL eller 0 = alle ukedager; ellers bit-maske)
 *   - spot_id (per-plass) vinner over listing-wide
 *
 * Brukes for både camping (per natt) og parkering (per døgn) — modellen er
 * identisk når parkering ble forenklet til per-dag-prising.
 */
export function resolveNightlyPrice(
  date: Date,
  basePrice: number,
  rules: PricingRule[],
  overrides: PricingOverride[],
): { price: number; source: PriceSource } {
  const iso = formatDate(date);
  const bit = weekdayBit(date);

  // 1) Override (spot-spesifikk vinner over listing-wide)
  const matchingOverrides = overrides
    .filter((o) => o.date === iso)
    .sort((a, b) => (b.spotId ? 1 : 0) - (a.spotId ? 1 : 0));
  const override = matchingOverrides[0];
  if (override) return { price: override.price, source: "override" };

  // 2) Sesong-bånd. Kandidater: kind=season, dato innenfor range,
  //    day_mask matcher (NULL/0 = alle dager). Sortert: spot-spesifikk vinner.
  const seasonCandidates = rules
    .filter((r) => {
      if (r.kind !== "season") return false;
      if (!r.startDate || !r.endDate) return false;
      if (iso < r.startDate || iso > r.endDate) return false;
      if (typeof r.dayMask === "number" && r.dayMask !== 0) {
        if ((r.dayMask & (1 << bit)) === 0) return false;
      }
      return true;
    })
    .sort((a, b) => (b.spotId ? 1 : 0) - (a.spotId ? 1 : 0));
  const seasonRule = seasonCandidates[0];
  if (seasonRule) return { price: seasonRule.price, source: "season" };

  // 3) Helg (dag-maske)
  const weekendRule = rules.find(
    (r) => r.kind === "weekend" && typeof r.dayMask === "number" && (r.dayMask & (1 << bit)) !== 0,
  );
  if (weekendRule) return { price: weekendRule.price, source: "weekend" };

  // 4) Base
  return { price: basePrice, source: "base" };
}

interface ResolveInput {
  listingId: string;
  checkIn: string;  // "YYYY-MM-DD"
  checkOut: string; // exclusive
  basePrice: number;
}

/**
 * Henter alle regler + overrides fra DB og bygger en per-dag breakdown.
 * Server-side. Bruker authenticated client siden regler har public read.
 */
export async function getNightlyPrices(input: ResolveInput): Promise<NightlyPrice[]> {
  const supabase = await createServerClient();

  const [rulesRes, overridesRes] = await Promise.all([
    supabase
      .from("listing_pricing_rules")
      .select("*")
      .eq("listing_id", input.listingId),
    supabase
      .from("listing_pricing_overrides")
      .select("*")
      .eq("listing_id", input.listingId)
      .gte("date", input.checkIn)
      .lt("date", input.checkOut),
  ]);

  const rules: PricingRule[] = (rulesRes.data || []).map(rowToRule);
  const overrides: PricingOverride[] = (overridesRes.data || []).map(rowToOverride);

  return buildBreakdown(input, rules, overrides);
}

/**
 * Variant som bruker service-role-client — for API-routes som kjører uten
 * Supabase-auth-cookie (f.eks. `/api/bookings/create` for iOS).
 */
export async function getNightlyPricesWithServiceClient(
  input: ResolveInput,
  url: string,
  serviceKey: string,
): Promise<NightlyPrice[]> {
  const supabase = createServiceClient(url, serviceKey);

  const [rulesRes, overridesRes] = await Promise.all([
    supabase
      .from("listing_pricing_rules")
      .select("*")
      .eq("listing_id", input.listingId),
    supabase
      .from("listing_pricing_overrides")
      .select("*")
      .eq("listing_id", input.listingId)
      .gte("date", input.checkIn)
      .lt("date", input.checkOut),
  ]);

  const rules: PricingRule[] = (rulesRes.data || []).map(rowToRule);
  const overrides: PricingOverride[] = (overridesRes.data || []).map(rowToOverride);

  return buildBreakdown(input, rules, overrides);
}

function buildBreakdown(
  input: ResolveInput,
  rules: PricingRule[],
  overrides: PricingOverride[],
): NightlyPrice[] {
  const breakdown: NightlyPrice[] = [];
  const cursor = parseDate(input.checkIn);
  const end = parseDate(input.checkOut);
  while (cursor < end) {
    const { price, source } = resolveNightlyPrice(cursor, input.basePrice, rules, overrides);
    breakdown.push({ date: formatDate(cursor), price, source });
    cursor.setDate(cursor.getDate() + 1);
  }
  return breakdown;
}

/** Summer pris-breakdown til total (før service-fee). */
export function applyPriceBreakdown(breakdown: NightlyPrice[]): number {
  return breakdown.reduce((sum, n) => sum + n.price, 0);
}

function rowToRule(row: Record<string, unknown>): PricingRule {
  return {
    id: row.id as string,
    listingId: row.listing_id as string,
    kind: row.kind as PricingRule["kind"],
    dayMask: (row.day_mask as number | null) ?? null,
    startDate: (row.start_date as string | null) ?? null,
    endDate: (row.end_date as string | null) ?? null,
    price: row.price as number,
    spotId: (row.spot_id as string | null) ?? null,
    colorIndex: (row.color_index as number | null) ?? null,
  };
}

function rowToOverride(row: Record<string, unknown>): PricingOverride {
  return {
    listingId: row.listing_id as string,
    date: row.date as string,
    price: row.price as number,
    spotId: (row.spot_id as string | null) ?? null,
  };
}

// MARK: - Lengre opphold (parkering)
//
// "Lengre opphold"-priser erstatter standard dagspris når booking dekker fulle
// perioder. Parkering bookes nå per dag (samme modell som camping per natt),
// så vi grupperer dagene greedy: floor(N/30) måneder + floor(rest/7) uker +
// rest enkelt-dager. Hver tier erstatter dagsbasen med en fast pris hvis den
// er gunstigere.

/** Returner "lengre opphold"-priser for en plass, eller fallback til base. */
export function getEffectiveLongerStayPrices(
  spot: {
    dailyPrice?: number | null;
    weeklyPrice?: number | null;
    monthlyPrice?: number | null;
  } | null | undefined,
): { dailyPrice: number; weeklyPrice: number; monthlyPrice: number } {
  return {
    dailyPrice: spot?.dailyPrice ?? 0,
    weeklyPrice: spot?.weeklyPrice ?? 0,
    monthlyPrice: spot?.monthlyPrice ?? 0,
  };
}

/**
 * Hent alle "Lengre opphold"-tier-priser fra en spot-marker. Bruker 0 som
 * fallback for hver tier-pris som ikke er satt — `applyLongerStayPricing`
 * ignorerer da tieren under stabling.
 */
export function spotLongerStayTiers(
  spot: {
    dailyPrice?: number | null;
    weeklyPrice?: number | null;
    monthlyPrice?: number | null;
    threeMonthPrice?: number | null;
    sixMonthPrice?: number | null;
    yearPrice?: number | null;
  } | null | undefined,
): {
  dailyPrice: number;
  weeklyPrice: number;
  monthlyPrice: number;
  threeMonthPrice: number;
  sixMonthPrice: number;
  yearPrice: number;
} {
  return {
    dailyPrice: spot?.dailyPrice ?? 0,
    weeklyPrice: spot?.weeklyPrice ?? 0,
    monthlyPrice: spot?.monthlyPrice ?? 0,
    threeMonthPrice: spot?.threeMonthPrice ?? 0,
    sixMonthPrice: spot?.sixMonthPrice ?? 0,
    yearPrice: spot?.yearPrice ?? 0,
  };
}

export interface LongerStayInput {
  /** Per-dag breakdown fra getNightlyPrices/getNightlyPricesWithServiceClient. */
  breakdown: NightlyPrice[];
  /** Pris (kr) for ett fullt døgn. 0 = ingen tilbud. @deprecated bruk ikke i UI lenger. */
  dailyPrice?: number;
  /** Pris (kr) for 7 påfølgende fulle døgn. 0 = ingen tilbud. */
  weeklyPrice: number;
  /** Pris (kr) for 30 påfølgende fulle døgn. 0 = ingen tilbud. */
  monthlyPrice: number;
  /** Pris (kr) for 90 påfølgende fulle døgn. 0 = ingen tilbud. */
  threeMonthPrice?: number;
  /** Pris (kr) for 180 påfølgende fulle døgn. 0 = ingen tilbud. */
  sixMonthPrice?: number;
  /** Pris (kr) for 365 påfølgende fulle døgn. 0 = ingen tilbud. */
  yearPrice?: number;
}

export interface LongerStayResult {
  /** Total etter rabatt. */
  total: number;
  /** Original total uten rabatt. */
  baseTotal: number;
  /** Sparte beløp (kr). */
  savings: number;
  /** Antall dager i bookingen. */
  fullDays: number;
  /** Hvordan rabatten er stablet. */
  tiers: {
    years: number;
    sixMonths: number;
    threeMonths: number;
    months: number;
    weeks: number;
    days: number;
  };
}

/**
 * Anvender "lengre opphold"-priser på en per-dag-breakdown. Tier-pris er den
 * faste kr-prisen som erstatter basisen for tier-perioden.
 *
 * Stables greedy fra lengste tier først: 365 → 180 → 90 → 30 → 7 → enkelt-dag.
 * "Daily"-tier (1 dag) er deprecated fordi det er identisk med standard-
 * dagsprisen — beholdt i input for bakoverkompat med eldre annonser.
 */
export function applyLongerStayPricing(input: LongerStayInput): LongerStayResult {
  const {
    breakdown,
    dailyPrice = 0,
    weeklyPrice,
    monthlyPrice,
    threeMonthPrice = 0,
    sixMonthPrice = 0,
    yearPrice = 0,
  } = input;
  const baseTotal = breakdown.reduce((s, n) => s + n.price, 0);
  const totalDays = breakdown.length;

  const noOffers =
    dailyPrice <= 0 &&
    weeklyPrice <= 0 &&
    monthlyPrice <= 0 &&
    threeMonthPrice <= 0 &&
    sixMonthPrice <= 0 &&
    yearPrice <= 0;

  if (noOffers) {
    return {
      total: baseTotal,
      baseTotal,
      savings: 0,
      fullDays: 0,
      tiers: { years: 0, sixMonths: 0, threeMonths: 0, months: 0, weeks: 0, days: 0 },
    };
  }

  let cursor = 0;
  let remaining = totalDays;
  let savings = 0;
  const tiers = { years: 0, sixMonths: 0, threeMonths: 0, months: 0, weeks: 0, days: 0 };

  const tierSavings = (baseSum: number, tierPrice: number): number => {
    if (tierPrice <= 0 || tierPrice >= baseSum) return 0;
    return baseSum - tierPrice;
  };

  const sumRange = (start: number, length: number): number =>
    breakdown.slice(start, start + length).reduce((s, n) => s + n.price, 0);

  while (yearPrice > 0 && remaining >= 365) {
    savings += tierSavings(sumRange(cursor, 365), yearPrice);
    tiers.years += 1;
    cursor += 365;
    remaining -= 365;
  }
  while (sixMonthPrice > 0 && remaining >= 180) {
    savings += tierSavings(sumRange(cursor, 180), sixMonthPrice);
    tiers.sixMonths += 1;
    cursor += 180;
    remaining -= 180;
  }
  while (threeMonthPrice > 0 && remaining >= 90) {
    savings += tierSavings(sumRange(cursor, 90), threeMonthPrice);
    tiers.threeMonths += 1;
    cursor += 90;
    remaining -= 90;
  }
  while (monthlyPrice > 0 && remaining >= 30) {
    savings += tierSavings(sumRange(cursor, 30), monthlyPrice);
    tiers.months += 1;
    cursor += 30;
    remaining -= 30;
  }
  while (weeklyPrice > 0 && remaining >= 7) {
    savings += tierSavings(sumRange(cursor, 7), weeklyPrice);
    tiers.weeks += 1;
    cursor += 7;
    remaining -= 7;
  }
  while (dailyPrice > 0 && remaining > 0) {
    savings += tierSavings(breakdown[cursor].price, dailyPrice);
    tiers.days += 1;
    cursor += 1;
    remaining -= 1;
  }

  const rounded = Math.round(savings);
  return {
    total: baseTotal - rounded,
    baseTotal,
    savings: rounded,
    fullDays: totalDays,
    tiers,
  };
}

/** @deprecated bruk LongerStayResult. */
export type DurationDiscountResult = LongerStayResult;
