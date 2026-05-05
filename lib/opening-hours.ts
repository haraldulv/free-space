import type { Listing, OpeningHours, SpotMarker, Weekday } from "@/types";
import { WEEKDAYS } from "@/types";

const TIME_RE = /^([01]\d|2[0-3]):([0-5]\d)$/;
const RANGE_RE = /^([01]\d|2[0-3]):([0-5]\d)-([01]\d|2[0-3]):([0-5]\d)$/;

/** JS Date.getDay() (0=Sun..6=Sat) → Weekday-key. */
const JS_DAY_TO_WEEKDAY: Weekday[] = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];

export function weekdayOf(date: Date): Weekday {
  return JS_DAY_TO_WEEKDAY[date.getDay()];
}

/** Parser "HH:MM-HH:MM" til {start, end} minutter siden midnatt. Returnerer null hvis ugyldig. */
export function parseOpeningRange(range: string): { start: number; end: number } | null {
  const m = RANGE_RE.exec(range);
  if (!m) return null;
  const start = Number(m[1]) * 60 + Number(m[2]);
  const end = Number(m[3]) * 60 + Number(m[4]);
  if (end <= start) return null;
  return { start, end };
}

export function formatTime(minutes: number): string {
  const h = Math.floor(minutes / 60).toString().padStart(2, "0");
  const m = (minutes % 60).toString().padStart(2, "0");
  return `${h}:${m}`;
}

/** Returnerer effektiv åpningstid for en spot — spot.openingHours overstyrer listing-nivå. */
export function effectiveOpeningHours(
  listing: Pick<Listing, "openingHours">,
  spot?: Pick<SpotMarker, "openingHours"> | null,
): OpeningHours | null {
  if (spot && spot.openingHours !== undefined && spot.openingHours !== null) return spot.openingHours;
  return listing.openingHours ?? null;
}

/** True hvis åpningstidene begrenser til mindre enn 24/7. */
export function hasLimitedHours(oh: OpeningHours | null | undefined): boolean {
  if (!oh) return false;
  return WEEKDAYS.some((d) => {
    const v = oh[d];
    if (v === null) return true; // stengt en dag
    if (typeof v !== "string") return false; // mangler felt — behandles som "ikke begrenset" ved lagring; se validate
    const r = parseOpeningRange(v);
    if (!r) return false;
    return !(r.start === 0 && r.end === 24 * 60);
  });
}

/** True hvis listing/spot er åpen hele datoen `date` (00:00–24:00). */
export function isOpenAllDay(oh: OpeningHours | null | undefined, date: Date): boolean {
  if (!oh) return true; // ingen åpningstid satt = døgnåpent
  const day = weekdayOf(date);
  const v = oh[day];
  if (!v) return false; // stengt eller udefinert
  const r = parseOpeningRange(v);
  if (!r) return false;
  return r.start === 0 && r.end === 24 * 60;
}

/** True hvis åpen i det hele tatt på datoen. */
export function isOpenAt(oh: OpeningHours | null | undefined, date: Date): boolean {
  if (!oh) return true;
  const v = oh[weekdayOf(date)];
  if (!v) return false;
  return parseOpeningRange(v) !== null;
}

/** Sjekk om alle dager i datoperioden (checkIn inklusiv, checkOut eksklusiv) er åpne. */
export function isOpenForRange(
  oh: OpeningHours | null | undefined,
  checkIn: Date,
  checkOut: Date,
): boolean {
  if (!oh) return true;
  const cur = new Date(checkIn);
  cur.setHours(0, 0, 0, 0);
  const end = new Date(checkOut);
  end.setHours(0, 0, 0, 0);
  while (cur < end) {
    if (!isOpenAt(oh, cur)) return false;
    cur.setDate(cur.getDate() + 1);
  }
  return true;
}

/** Validerer åpningstid — alle ikke-null verdier må være gyldige "HH:MM-HH:MM". */
export function validateOpeningHours(oh: OpeningHours | null | undefined): { valid: boolean; error?: string } {
  if (!oh) return { valid: true };
  for (const day of WEEKDAYS) {
    const v = oh[day];
    if (v === undefined || v === null) continue;
    if (typeof v !== "string" || !RANGE_RE.test(v)) return { valid: false, error: `Ugyldig format for ${day}: "${v}"` };
    const r = parseOpeningRange(v);
    if (!r) return { valid: false, error: `Sluttid må være etter starttid for ${day}` };
  }
  return { valid: true };
}

export const DEFAULT_LIMITED_HOURS: OpeningHours = {
  mon: "09:00-17:00",
  tue: "09:00-17:00",
  wed: "09:00-17:00",
  thu: "09:00-17:00",
  fri: "09:00-17:00",
  sat: null,
  sun: null,
};

/** True hvis det er gyldig HH:MM. */
export function isValidTime(t: string): boolean {
  return TIME_RE.test(t);
}
