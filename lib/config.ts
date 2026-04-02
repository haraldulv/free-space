/** Brand name used across the platform */
export const BRAND_NAME = "Tuno";

/** Site URL — used for QR codes, Stripe callbacks, etc. */
export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";

/** Platform service fee rate (10% = 0.10). Charged on top of listing price. */
export const SERVICE_FEE_RATE = 0.10;

/** Hours after check-in before host payout is processed */
export const HOST_PAYOUT_DELAY_HOURS = 24;
