import { createClient as createServerClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";

export type PriceSource = "base" | "weekend" | "season" | "override";

export interface NightlyPrice {
  /** ISO dato "YYYY-MM-DD" (natten som starter denne datoen) */
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
}

export interface PricingOverride {
  listingId: string;
  date: string;
  price: number;
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
 */
export function resolveNightlyPrice(
  date: Date,
  basePrice: number,
  rules: PricingRule[],
  overrides: PricingOverride[],
): { price: number; source: PriceSource } {
  const iso = formatDate(date);

  // 1) Override
  const override = overrides.find((o) => o.date === iso);
  if (override) return { price: override.price, source: "override" };

  // 2) Sesong (velg første matchende — ingen overlap forventet)
  const seasonRule = rules.find(
    (r) =>
      r.kind === "season" &&
      r.startDate &&
      r.endDate &&
      iso >= r.startDate &&
      iso <= r.endDate,
  );
  if (seasonRule) return { price: seasonRule.price, source: "season" };

  // 3) Helg (dag-maske)
  const bit = weekdayBit(date);
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
 * Henter alle regler + overrides fra DB og bygger en per-natt breakdown.
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
  };
}

function rowToOverride(row: Record<string, unknown>): PricingOverride {
  return {
    listingId: row.listing_id as string,
    date: row.date as string,
    price: row.price as number,
  };
}
