/** Brand name used across the platform. */
export const BRAND_NAME = "Tuno";

/** Site URL — used for QR codes, Stripe callbacks, etc. */
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";

/** Platform service fee rate (10% = 0.10). Charged on top of listing price. */
export const SERVICE_FEE_RATE = 0.10;

/** Hours after check-in before host payout is processed */
export const HOST_PAYOUT_DELAY_HOURS = 24;

/**
 * Maks antall netter som kan bookes via "Book nå" på instant-annonser.
 * Lengre opphold krever alltid godkjenning fra utleier — beskytter mot
 * uønskede langtidsopphold på plasser med instant_booking=true.
 */
export const MAX_INSTANT_NIGHTS = 7;

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
