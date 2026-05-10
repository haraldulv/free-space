/**
 * Vipps OIDC-konfigurasjon. Holder env-validering og base-URL ett sted.
 *
 * Returnerer null om credentials mangler, slik at routes kan svare 501
 * `vipps_not_configured` istedenfor å crashe ved import.
 */

export type VippsConfig = {
  env: "test" | "production";
  baseUrl: string;
  clientId: string;
  clientSecret: string;
  subscriptionKey: string;
  msn: string;
  redirectUri: string;
};

export function getVippsConfig(): VippsConfig | null {
  const clientId = process.env.VIPPS_CLIENT_ID;
  const clientSecret = process.env.VIPPS_CLIENT_SECRET;
  const subscriptionKey = process.env.VIPPS_SUBSCRIPTION_KEY;
  const msn = process.env.VIPPS_MSN;
  const redirectUri = process.env.VIPPS_REDIRECT_URI;

  if (!clientId || !clientSecret || !subscriptionKey || !msn || !redirectUri) {
    return null;
  }

  const env = process.env.VIPPS_ENV === "production" ? "production" : "test";
  const baseUrl =
    env === "production" ? "https://api.vipps.no" : "https://apitest.vipps.no";

  return {
    env,
    baseUrl,
    clientId,
    clientSecret,
    subscriptionKey,
    msn,
    redirectUri,
  };
}

/** Standard scopes for Fase 1 — login. */
export const VIPPS_LOGIN_SCOPES = ["openid", "name", "email", "phoneNumber"];

/**
 * Scopes for Fase 3 — Bli utleier henter personnummer (nin) + fødselsdato
 * (birthDate) + adresse direkte fra Vipps og sender til Stripe Connect.
 * `nin` er beskyttet — krever produktgodkjenning fra Vipps for live-bruk.
 */
export const VIPPS_NIN_SCOPES = [
  "openid",
  "name",
  "email",
  "phoneNumber",
  "birthDate",
  "address",
  "nin",
];
