/** Brand name used across the platform. */
export const BRAND_NAME = "Tuno";

/** Site URL — used for QR codes, Stripe callbacks, etc. */
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";

/** App Store-lenke (id-formen tåler navnebytte i App Store). */
export const APP_STORE_URL = "https://apps.apple.com/no/app/id6761529990";

/** Platform service fee rate (10% = 0.10). Charged on top of listing price. */
export const SERVICE_FEE_RATE = 0.10;

/**
 * Adresser som får ALLE automatiske varsler (moderering, rapporter,
 * vaktbikkje, audit). Styrer også hvilke admin-brukere som får push/in-app
 * (se lib/admins.ts). Gmail er med så levering ikke avhenger av
 * videresending fra Proton (MX for tuno.no er Proton Mail).
 */
export const ADMIN_EMAILS = ["harald@tuno.no", "haraldsalvesen@gmail.com"];

/**
 * Om AI-godkjente annonser publiseres automatisk. false = alt må godkjennes
 * manuelt i /admin/moderering (AI-resultatet vises som hjelp).
 */
export const AUTO_APPROVE_LISTINGS = true;

/** Flaggede annonser uten admin-avgjørelse avvises automatisk etter så mange timer. */
export const FLAGGED_AUTO_REJECT_HOURS = 48;

/**
 * Nødbryter: hvis flere enn så mange nye brukere på 10 minutter, stenger
 * vaktbikkja registrering automatisk (app_settings.signups_enabled=false)
 * og varsler admin. Slås på igjen i /admin/moderering.
 */
export const SIGNUP_BURST_LIMIT_PER_10_MIN = 25;

/** Hours after check-in before host payout is processed */
export const HOST_PAYOUT_DELAY_HOURS = 24;

/**
 * Maks antall netter som kan bookes via "Book nå" på instant-annonser.
 * Lengre opphold krever alltid godkjenning fra utleier — beskytter mot
 * uønskede langtidsopphold på plasser med instant_booking=true.
 */
export const MAX_INSTANT_NIGHTS = 7;

/**
 * Asker-pivoten: web-flatene er parkering-først. Styrer forside-innhold og
 * søke-defaults (kategori parkering). Speiler iOS AppConfig.parkingOnly.
 * Escape-hatch: sett NEXT_PUBLIC_PARKING_ONLY=false for å slå camping på igjen.
 */
export const PARKING_ONLY = process.env.NEXT_PUBLIC_PARKING_ONLY !== "false";

/**
 * Parkering: direktebooking tillates opp til en hel månedsplass (30 dager)
 * med litt margin. Camping beholder 7-netters-grensen over. Uten denne ville
 * «Fast månedsplass» på en direkteannonse havnet i manual capture, som
 * appen ikke håndterer som vanlig betaling.
 */
export const PARKING_MAX_INSTANT_DAYS = 31;

/**
 * Split av `total_price` (det gjesten betaler) til (host-andel, Tunos gebyr).
 * Host-andelen er listing-prisen de selv har satt; gebyret er lagt på toppen.
 *
 *   totalPrice = subtotal + round(subtotal * SERVICE_FEE_RATE)
 *
 * → fee = round(totalPrice * SERVICE_FEE_RATE / (1 + SERVICE_FEE_RATE))
 * → hostShare = totalPrice - fee
 *
 * Returner alltid heltall i NOK. Holder oss konsistente mellom booking-opprettelse
 * (create/route.ts), payout-cron (process-payouts), kansellering (cancellation.ts),
 * stats (stats.ts) og iOS-visningen i HostRequestsView.
 */
export function splitHostAndFee(totalPriceNok: number): { hostShareNok: number; feeNok: number } {
  const feeNok = Math.round(totalPriceNok * SERVICE_FEE_RATE / (1 + SERVICE_FEE_RATE));
  return { hostShareNok: totalPriceNok - feeNok, feeNok };
}
