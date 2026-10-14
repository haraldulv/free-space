// Delt dag-logikk for bookinger med multi-velg datoer (parkering).
// En booking har check_in/check_out som konvolutt (første/siste dag) og,
// for parkering, booked_dates: eksplisitt liste av "YYYY-MM-DD" som er
// autoritativ når satt (kan ha hull, f.eks. man-ons flere uker på rad).
// Camping bruker fortsatt eksklusiv utsjekksdag og har aldri booked_dates.

export interface BookingDayRow {
  check_in: string;
  check_out: string;
  booked_dates?: string[] | null;
  selected_spot_ids?: string[] | null;
}

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** Ekspander en periode til dagliste. UTC-basert, tidssone-uavhengig. */
export function expandDays(checkIn: string, checkOut: string, inclusiveEnd: boolean): string[] {
  const days: string[] = [];
  const cursor = new Date(checkIn);
  const end = new Date(checkOut);
  if (Number.isNaN(cursor.getTime()) || Number.isNaN(end.getTime())) return days;
  while (inclusiveEnd ? cursor <= end : cursor < end) {
    days.push(cursor.toISOString().slice(0, 10));
    cursor.setUTCDate(cursor.getUTCDate() + 1);
  }
  return days;
}

/** Dagene en booking-rad faktisk opptar. */
export function bookingDays(row: BookingDayRow, inclusiveEnd: boolean): string[] {
  const explicit = row.booked_dates;
  if (Array.isArray(explicit) && explicit.length > 0) {
    return explicit.filter((d) => typeof d === "string" && ISO_DATE.test(d));
  }
  return expandDays(row.check_in, row.check_out, inclusiveEnd);
}

/**
 * Valider og normaliser en klient-innsendt dagliste: ISO-format, unike,
 * sortert. Returnerer null når lista er ugyldig eller tom.
 */
export function normalizeBookedDates(input: unknown): string[] | null {
  if (!Array.isArray(input) || input.length === 0) return null;
  const seen = new Set<string>();
  for (const d of input) {
    if (typeof d !== "string" || !ISO_DATE.test(d)) return null;
    if (Number.isNaN(new Date(d).getTime())) return null;
    seen.add(d);
  }
  return [...seen].sort();
}

/**
 * Høyeste belegg (antall opptatte enheter) over de forespurte dagene.
 * En rad teller selected_spot_ids.length enheter, ellers 1 — samme
 * konvensjon som create-rutens envelope-telling, men per dag, slik at
 * ikke-overlappende bookinger innenfor samme konvolutt ikke stenger
 * hverandre ute.
 */
export function peakOccupancy(
  rows: BookingDayRow[],
  requestedDays: string[],
  inclusiveEnd: boolean,
): number {
  let peak = 0;
  for (const count of dayOccupancy(rows, requestedDays, inclusiveEnd).values()) {
    if (count > peak) peak = count;
  }
  return peak;
}

/** Belegg (antall opptatte enheter) per forespurt dag. */
export function dayOccupancy(
  rows: BookingDayRow[],
  requestedDays: string[],
  inclusiveEnd: boolean,
): Map<string, number> {
  const counts = new Map<string, number>();
  if (requestedDays.length === 0 || rows.length === 0) return counts;
  const requested = new Set(requestedDays);
  for (const row of rows) {
    const units = row.selected_spot_ids?.length || 1;
    for (const day of bookingDays(row, inclusiveEnd)) {
      if (!requested.has(day)) continue;
      counts.set(day, (counts.get(day) ?? 0) + units);
    }
  }
  return counts;
}

/**
 * Første forespurte dag UTEN ledig kapasitet for en parkering-annonse, eller
 * null når alle dager har plass. Kapasitet per dag = spots minus plassene
 * verten manuelt har blokkert den dagen (spot_markers[].blockedDates);
 * dager i annonse-nivå blocked_dates har kapasitet 0. Belegg telles per dag
 * så en man-ons-booking ikke stenger tor-fre.
 */
export function firstUnavailableParkingDay(args: {
  requestedDays: string[];
  rows: BookingDayRow[];
  totalSpots: number;
  spotMarkers?: { blockedDates?: string[] | null }[] | null;
  listingBlockedDates?: string[] | null;
}): string | null {
  const { requestedDays, rows, totalSpots } = args;
  const markers = args.spotMarkers ?? [];
  const listingBlocked = new Set(args.listingBlockedDates ?? []);
  const occupancy = dayOccupancy(rows, requestedDays, true);
  for (const day of requestedDays) {
    if (listingBlocked.has(day)) return day;
    const blockedSpots = markers.filter((m) => m.blockedDates?.includes(day)).length;
    const capacity = Math.max(0, totalSpots - blockedSpots);
    if ((occupancy.get(day) ?? 0) >= capacity) return day;
  }
  return null;
}

/** Spot-id-er som er opptatt på minst én av de forespurte dagene. */
export function occupiedSpotIds(
  rows: BookingDayRow[],
  requestedDays: string[],
  inclusiveEnd: boolean,
): Set<string> {
  const occupied = new Set<string>();
  const requested = new Set(requestedDays);
  for (const row of rows) {
    const ids = row.selected_spot_ids;
    if (!ids || ids.length === 0) continue;
    if (bookingDays(row, inclusiveEnd).some((day) => requested.has(day))) {
      ids.forEach((id) => occupied.add(id));
    }
  }
  return occupied;
}
