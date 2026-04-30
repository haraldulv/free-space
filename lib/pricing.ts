import { createClient as createServerClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";

export type PriceSource = "base" | "weekend" | "season" | "override";
export type HourlyPriceSource = "base" | "hourly" | "override" | "unavailable";

export type AvailabilityMode = "always" | "bands";

export interface NightlyPrice {
  /** ISO dato "YYYY-MM-DD" (natten som starter denne datoen) */
  date: string;
  price: number;
  source: PriceSource;
}

export interface HourlyPrice {
  /** ISO 8601 timestamp for time-blokken (Europe/Oslo). */
  hourAt: string;
  price: number;
  source: HourlyPriceSource;
}

export interface PricingRule {
  id: string;
  listingId: string;
  kind: "weekend" | "season" | "hourly";
  dayMask: number | null;        // bitmask: bit 0 = Mandag, bit 6 = Søndag
  startDate: string | null;      // for 'season'
  endDate: string | null;        // for 'season', inclusive
  /** Hourly bånd: time 0..23 (inklusiv). NULL ellers. */
  startHour: number | null;
  /** Hourly bånd: time 1..24 (eksklusiv). NULL ellers. */
  endHour: number | null;
  /** Hourly bånd: minutt 0 eller 30. Default 0. */
  startMinute: number;
  /** Hourly bånd: minutt 0 eller 30. Default 0. */
  endMinute: number;
  price: number;
  /** Hvilken plass (SpotMarker.id) regelen gjelder. NULL = listing-wide. */
  spotId: string | null;
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

// MARK: - Hourly pricing (parkering per time)

interface ResolveHourlyInput {
  listingId: string;
  /** ISO 8601 timestamp for ankomst (Europe/Oslo forventet). */
  checkInAt: string;
  /** ISO 8601 timestamp for avgang (Europe/Oslo forventet). */
  checkOutAt: string;
  /** Base hourly-pris (kr/time). */
  basePrice: number;
  /** Spot som booking gjelder for. NULL = listing-wide kun. */
  spotId?: string | null;
  /** Plassens availability_mode (fra listings-tabellen). Default 'always'. */
  availabilityMode?: AvailabilityMode;
}

/**
 * Returnerer en Oslo-TZ-projeksjon av et timestamp (date + hour + weekday-bit).
 * Server kjører i UTC, så vi må eksplisitt konvertere før .getHours()/weekdayBit.
 */
function osloHourParts(d: Date): { dateIso: string; hour: number; weekdayBit: number } {
  // Intl gir oss part-by-part — bruker en kjent TZ-formatter.
  const fmt = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Oslo",
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", weekday: "short", hourCycle: "h23",
  });
  const parts = fmt.formatToParts(d);
  const get = (t: string) => parts.find((p) => p.type === t)?.value || "";
  const dateIso = `${get("year")}-${get("month")}-${get("day")}`;
  const hour = parseInt(get("hour"), 10);
  // Mon=0 ... Sun=6 — Intl returnerer "Mon", "Tue" etc.
  const wdMap: Record<string, number> = { Mon: 0, Tue: 1, Wed: 2, Thu: 3, Fri: 4, Sat: 5, Sun: 6 };
  const weekdayBit = wdMap[get("weekday")] ?? 0;
  return { dateIso, hour, weekdayBit };
}

/**
 * Server-autoritativ hourly-resolution. Presedens:
 *   1) override (per dato — spot-spesifikk vinner over listing-wide)
 *   2) hourly-bånd (spot-spesifikk + dato-spesifikk vinner i den rekkefølgen)
 *   3) unavailable (kun når mode='bands' og det finnes båndregler men ingen match)
 *   4) base hourly-pris
 *
 * MERK: alle tids-sammenligninger gjøres i Europe/Oslo, uavhengig av server-TZ.
 *
 * `rules` og `overrides` skal være pre-filtrert til de som er relevante for
 * målet (spot_id IS NULL OR spot_id=targetSpotId), eller alle hvis ikke per-spot.
 */
export function resolveHourlyPrice(
  hourCursor: Date,
  basePrice: number,
  rules: PricingRule[],
  overrides: PricingOverride[],
  availabilityMode: AvailabilityMode = "always",
): { price: number; source: HourlyPriceSource } {
  const { dateIso, hour, weekdayBit: bit } = osloHourParts(hourCursor);

  // 1) Override (per dato — gjelder hele døgnet). Spot-spesifikk vinner over listing-wide.
  const matchingOverrides = overrides
    .filter((o) => o.date === dateIso)
    .sort((a, b) => (b.spotId ? 1 : 0) - (a.spotId ? 1 : 0));
  const override = matchingOverrides[0];
  if (override) return { price: override.price, source: "override" };

  // 2) Hourly-bånd. Spot-spesifikk vinner over listing-wide, dato-spesifikk vinner over allWeeks.
  const hourlyRules = rules.filter((r) => r.kind === "hourly");
  const matchingBands = hourlyRules.filter((r) => {
    if (typeof r.dayMask !== "number") return false;
    if (r.startHour === null || r.endHour === null) return false;
    if (r.startDate && dateIso < r.startDate) return false;
    if (r.endDate && dateIso > r.endDate) return false;
    const dayMatches = (r.dayMask & (1 << bit)) !== 0;
    // Booking-time tikker i hele timer; båndet kan være finere (halvtimer).
    // Time h dekkes hvis hele intervallet [h*60, (h+1)*60) ligger innenfor båndet.
    const bandStartMin = r.startHour * 60 + r.startMinute;
    const bandEndMin = r.endHour * 60 + r.endMinute;
    const hourStartMin = hour * 60;
    const hourEndMin = hourStartMin + 60;
    const hourMatches = hourStartMin >= bandStartMin && hourEndMin <= bandEndMin;
    return dayMatches && hourMatches;
  });
  matchingBands.sort((a, b) => {
    const aSpot = a.spotId ? 1 : 0;
    const bSpot = b.spotId ? 1 : 0;
    if (aSpot !== bSpot) return bSpot - aSpot;
    const aDate = a.startDate !== null || a.endDate !== null ? 1 : 0;
    const bDate = b.startDate !== null || b.endDate !== null ? 1 : 0;
    return bDate - aDate;
  });
  const band = matchingBands[0];
  if (band) return { price: band.price, source: "hourly" };

  // 3) Unavailable-sentinel: kun når mode='bands' OG det finnes båndregler i pre-filtrert
  // sett, men ingen matcher denne timen. Da er plassen eksplisitt utenfor åpningstiden.
  if (availabilityMode === "bands" && hourlyRules.length > 0) {
    return { price: 0, source: "unavailable" };
  }

  // 4) Base
  return { price: basePrice, source: "base" };
}

export async function getHourlyPrices(input: ResolveHourlyInput): Promise<HourlyPrice[]> {
  const supabase = await createServerClient();
  const startDate = input.checkInAt.slice(0, 10);
  const endDate = input.checkOutAt.slice(0, 10);

  const [rulesRes, overridesRes] = await Promise.all([
    supabase
      .from("listing_pricing_rules")
      .select("*")
      .eq("listing_id", input.listingId),
    supabase
      .from("listing_pricing_overrides")
      .select("*")
      .eq("listing_id", input.listingId)
      .gte("date", startDate)
      .lte("date", endDate),
  ]);

  const rules: PricingRule[] = (rulesRes.data || []).map(rowToRule);
  const overrides: PricingOverride[] = (overridesRes.data || []).map(rowToOverride);

  return buildHourlyBreakdown(input, rules, overrides);
}

export async function getHourlyPricesWithServiceClient(
  input: ResolveHourlyInput,
  url: string,
  serviceKey: string,
): Promise<HourlyPrice[]> {
  const supabase = createServiceClient(url, serviceKey);
  const startDate = input.checkInAt.slice(0, 10);
  const endDate = input.checkOutAt.slice(0, 10);

  const [rulesRes, overridesRes] = await Promise.all([
    supabase
      .from("listing_pricing_rules")
      .select("*")
      .eq("listing_id", input.listingId),
    supabase
      .from("listing_pricing_overrides")
      .select("*")
      .eq("listing_id", input.listingId)
      .gte("date", startDate)
      .lte("date", endDate),
  ]);

  const rules: PricingRule[] = (rulesRes.data || []).map(rowToRule);
  const overrides: PricingOverride[] = (overridesRes.data || []).map(rowToOverride);

  return buildHourlyBreakdown(input, rules, overrides);
}

function buildHourlyBreakdown(
  input: ResolveHourlyInput,
  rules: PricingRule[],
  overrides: PricingOverride[],
): HourlyPrice[] {
  const result: HourlyPrice[] = [];
  const cursor = new Date(input.checkInAt);
  const end = new Date(input.checkOutAt);
  const mode = input.availabilityMode ?? "always";

  // Pre-filter til spot-relevante regler/overrides: spot_id IS NULL OR spot_id=target.
  const spotId = input.spotId ?? null;
  const filteredRules = spotId
    ? rules.filter((r) => r.spotId === null || r.spotId === spotId)
    : rules.filter((r) => r.spotId === null);
  const filteredOverrides = spotId
    ? overrides.filter((o) => o.spotId === null || o.spotId === spotId)
    : overrides.filter((o) => o.spotId === null);

  while (cursor < end) {
    const { price, source } = resolveHourlyPrice(
      cursor,
      input.basePrice,
      filteredRules,
      filteredOverrides,
      mode,
    );
    result.push({ hourAt: cursor.toISOString(), price, source });
    cursor.setHours(cursor.getHours() + 1);
  }
  return result;
}

/** Summer hourly pris-breakdown til total (før service-fee). */
export function applyHourlyPriceBreakdown(breakdown: HourlyPrice[]): number {
  return breakdown.reduce((sum, h) => sum + h.price, 0);
}

function rowToRule(row: Record<string, unknown>): PricingRule {
  return {
    id: row.id as string,
    listingId: row.listing_id as string,
    kind: row.kind as PricingRule["kind"],
    dayMask: (row.day_mask as number | null) ?? null,
    startDate: (row.start_date as string | null) ?? null,
    endDate: (row.end_date as string | null) ?? null,
    startHour: (row.start_hour as number | null) ?? null,
    endHour: (row.end_hour as number | null) ?? null,
    startMinute: (row.start_minute as number | null) ?? 0,
    endMinute: (row.end_minute as number | null) ?? 0,
    price: row.price as number,
    spotId: (row.spot_id as string | null) ?? null,
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

/** Hjelper: returner true hvis breakdown inneholder en time markert som unavailable. */
export function hourlyBreakdownHasUnavailable(breakdown: HourlyPrice[]): boolean {
  return breakdown.some((h) => h.source === "unavailable");
}
