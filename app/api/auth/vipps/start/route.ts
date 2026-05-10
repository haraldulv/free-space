import { NextRequest, NextResponse } from "next/server";
import { cookies } from "next/headers";
import {
  getVippsConfig,
  VIPPS_LOGIN_SCOPES,
  VIPPS_NIN_SCOPES,
} from "@/lib/vipps/config";
import {
  buildAuthorizeUrl,
  generatePkcePair,
  generateState,
} from "@/lib/vipps/oidc";

const COOKIE_PREFIX = "vipps_";
const COOKIE_TTL = 60 * 10; // 10 min

export async function GET(req: NextRequest) {
  const config = getVippsConfig();
  if (!config) {
    return NextResponse.json(
      { error: "vipps_not_configured" },
      { status: 501 }
    );
  }

  const ret = req.nextUrl.searchParams.get("return") || "/dashboard";
  // Bare lokale paths godtas — beskytter mot open redirect.
  const safeReturn = ret.startsWith("/") ? ret : "/dashboard";

  // Native-flow (iOS-app via ASWebAuthenticationSession) trenger annen
  // retur enn web. I stedet for å sette session-cookie via magic-link
  // returnerer vi token_hash til appen som veksler det med verifyOTP.
  const isNative = req.nextUrl.searchParams.get("native") === "1";

  // purpose=nin er Fase 3-flyten: bruker er allerede innlogget og henter
  // personnummer/adresse til Stripe Connect. Annen sikkerhetspolicy:
  // userinfo skal ALDRI tilbake til klient og IKKE persisteres i DB.
  const purpose =
    req.nextUrl.searchParams.get("purpose") === "nin" ? "nin" : "login";

  // Native-intent: iOS-appen genererer en engangs-uuid via
  // POST /api/auth/vipps/native-intent og sender den inn her. Den lagres
  // som cookie og leses i callback for å koble nin-flyten til riktig bruker
  // uten å lene seg på SSR-session-cookie (som ikke finnes i native).
  const intent = req.nextUrl.searchParams.get("intent");
  const safeIntent =
    intent && /^[0-9a-f-]{36}$/i.test(intent) ? intent : null;

  const state = generateState();
  const { verifier, challenge } = generatePkcePair();

  const scopes = purpose === "nin" ? VIPPS_NIN_SCOPES : VIPPS_LOGIN_SCOPES;
  const url = buildAuthorizeUrl({
    config,
    state,
    codeChallenge: challenge,
    scopes,
  });

  const jar = await cookies();
  const cookieOpts = {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    path: "/api/auth/vipps",
    maxAge: COOKIE_TTL,
  };
  jar.set(`${COOKIE_PREFIX}state`, state, cookieOpts);
  jar.set(`${COOKIE_PREFIX}verifier`, verifier, cookieOpts);
  jar.set(`${COOKIE_PREFIX}return`, safeReturn, cookieOpts);
  jar.set(`${COOKIE_PREFIX}purpose`, purpose, cookieOpts);
  if (isNative) {
    jar.set(`${COOKIE_PREFIX}native`, "1", cookieOpts);
  }
  if (safeIntent) {
    jar.set(`${COOKIE_PREFIX}intent`, safeIntent, cookieOpts);
  }

  return NextResponse.redirect(url);
}
