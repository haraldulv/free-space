import { nb, enGB, de } from "date-fns/locale";
import type { Locale as DateFnsLocale } from "date-fns";

export type AppLocale = "nb" | "en" | "de";

/** BCP 47-tag for `toLocaleDateString` / `Intl.NumberFormat` etc. */
export function bcpLocale(locale: string): string {
  switch (locale) {
    case "en": return "en-GB";
    case "de": return "de-DE";
    default: return "nb-NO";
  }
}

/** BCP 47-tag for tall-formatering (USD-style tusentallsseparator for en). */
export function numberLocale(locale: string): string {
  switch (locale) {
    case "en": return "en-US";
    case "de": return "de-DE";
    default: return "nb-NO";
  }
}

/** date-fns-locale for `formatDistanceToNow`, `format` osv. */
export function dateFnsLocale(locale: string): DateFnsLocale {
  switch (locale) {
    case "en": return enGB;
    case "de": return de;
    default: return nb;
  }
}

/** Stripe Elements-locale (kun språkkoder Stripe støtter). */
export function stripeLocale(locale: string): "nb" | "en" | "de" {
  if (locale === "en") return "en";
  if (locale === "de") return "de";
  return "nb";
}
