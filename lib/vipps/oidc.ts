import crypto from "node:crypto";
import { VippsConfig } from "./config";

export type VippsTokens = {
  access_token: string;
  id_token: string;
  refresh_token?: string;
  expires_in: number;
  token_type: string;
};

export type VippsAddress = {
  street_address?: string;
  postal_code?: string;
  region?: string;
  country?: string;
  formatted?: string;
  address_type?: string;
};

export type VippsUserinfo = {
  sub: string;
  name?: string;
  given_name?: string;
  family_name?: string;
  email?: string;
  email_verified?: boolean;
  phone_number?: string;
  // YYYY-MM-DD (krever scope=birthDate)
  birthdate?: string;
  // 11-sifret norsk fødselsnummer (krever scope=nin, godkjent produkt)
  nin?: string;
  // Vipps returnerer enten objekt eller array av adresser
  address?: VippsAddress | VippsAddress[];
};

/** RFC 7636 PKCE: code_verifier + S256-challenge. */
export function generatePkcePair() {
  const verifier = base64UrlEncode(crypto.randomBytes(32));
  const challenge = base64UrlEncode(
    crypto.createHash("sha256").update(verifier).digest()
  );
  return { verifier, challenge };
}

export function generateState() {
  return base64UrlEncode(crypto.randomBytes(24));
}

function base64UrlEncode(buf: Buffer | string) {
  return (typeof buf === "string" ? Buffer.from(buf) : buf)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

export function buildAuthorizeUrl(opts: {
  config: VippsConfig;
  state: string;
  codeChallenge: string;
  scopes: string[];
}): string {
  const { config, state, codeChallenge, scopes } = opts;
  const url = new URL(
    "/access-management-1.0/access/oauth2/auth",
    config.baseUrl
  );
  url.searchParams.set("client_id", config.clientId);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("redirect_uri", config.redirectUri);
  url.searchParams.set("scope", scopes.join(" "));
  url.searchParams.set("state", state);
  url.searchParams.set("code_challenge", codeChallenge);
  url.searchParams.set("code_challenge_method", "S256");
  url.searchParams.set("merchant_serial_number", config.msn);
  return url.toString();
}

export async function exchangeCodeForTokens(opts: {
  config: VippsConfig;
  code: string;
  codeVerifier: string;
}): Promise<VippsTokens> {
  const { config, code, codeVerifier } = opts;
  const body = new URLSearchParams({
    grant_type: "authorization_code",
    code,
    redirect_uri: config.redirectUri,
    client_id: config.clientId,
    code_verifier: codeVerifier,
  });

  const basic = Buffer.from(
    `${config.clientId}:${config.clientSecret}`
  ).toString("base64");

  const res = await fetch(
    `${config.baseUrl}/access-management-1.0/access/oauth2/token`,
    {
      method: "POST",
      headers: {
        Authorization: `Basic ${basic}`,
        "Content-Type": "application/x-www-form-urlencoded",
        "Ocp-Apim-Subscription-Key": config.subscriptionKey,
        "Merchant-Serial-Number": config.msn,
      },
      body: body.toString(),
    }
  );

  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`Vipps token exchange failed: ${res.status} ${txt}`);
  }
  return res.json();
}

export async function fetchUserinfo(opts: {
  config: VippsConfig;
  accessToken: string;
}): Promise<VippsUserinfo> {
  const res = await fetch(
    `${opts.config.baseUrl}/vipps-userinfo-api/userinfo`,
    {
      headers: {
        Authorization: `Bearer ${opts.accessToken}`,
        "Ocp-Apim-Subscription-Key": opts.config.subscriptionKey,
        "Merchant-Serial-Number": opts.config.msn,
      },
    }
  );
  if (!res.ok) {
    const txt = await res.text();
    throw new Error(`Vipps userinfo failed: ${res.status} ${txt}`);
  }
  return res.json();
}
