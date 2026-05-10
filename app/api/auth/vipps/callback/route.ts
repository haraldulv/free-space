import { NextRequest, NextResponse } from "next/server";
import { cookies } from "next/headers";
import Stripe from "stripe";
import { createClient as createSupabase } from "@supabase/supabase-js";
import { getVippsConfig } from "@/lib/vipps/config";
import {
  exchangeCodeForTokens,
  fetchUserinfo,
  type VippsAddress,
  type VippsUserinfo,
} from "@/lib/vipps/oidc";
import { stripe } from "@/lib/stripe";
import { createClient as createSSRClient } from "@/lib/supabase/server";

const COOKIE_PREFIX = "vipps_";

export async function GET(req: NextRequest) {
  const config = getVippsConfig();
  if (!config) {
    return NextResponse.json(
      { error: "vipps_not_configured" },
      { status: 501 }
    );
  }

  const code = req.nextUrl.searchParams.get("code");
  const state = req.nextUrl.searchParams.get("state");
  const errorParam = req.nextUrl.searchParams.get("error");
  if (errorParam || !code || !state) {
    return redirectToLogin(req, errorParam || "missing_code");
  }

  const jar = await cookies();
  const cookieState = jar.get(`${COOKIE_PREFIX}state`)?.value;
  const verifier = jar.get(`${COOKIE_PREFIX}verifier`)?.value;
  const ret = jar.get(`${COOKIE_PREFIX}return`)?.value || "/dashboard";
  const isNative = jar.get(`${COOKIE_PREFIX}native`)?.value === "1";
  const purpose = jar.get(`${COOKIE_PREFIX}purpose`)?.value || "login";
  const intent = jar.get(`${COOKIE_PREFIX}intent`)?.value || null;

  if (!cookieState || !verifier || cookieState !== state) {
    return redirectToLogin(req, "state_mismatch");
  }

  // Tøm engangs-cookies — uavhengig av hva som skjer videre.
  jar.delete(`${COOKIE_PREFIX}state`);
  jar.delete(`${COOKIE_PREFIX}verifier`);
  jar.delete(`${COOKIE_PREFIX}return`);
  jar.delete(`${COOKIE_PREFIX}native`);
  jar.delete(`${COOKIE_PREFIX}purpose`);
  jar.delete(`${COOKIE_PREFIX}intent`);

  let userinfo;
  try {
    const tokens = await exchangeCodeForTokens({
      config,
      code,
      codeVerifier: verifier,
    });
    userinfo = await fetchUserinfo({
      config,
      accessToken: tokens.access_token,
    });
  } catch (e) {
    console.error("Vipps OIDC error", e);
    return redirectToLogin(req, "vipps_token_error");
  }

  if (!userinfo.email) {
    return redirectToLogin(req, "vipps_no_email");
  }

  const supabaseAdmin = createSupabase(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );

  // Fase 3: nin-flow er kun for innloggede brukere som henter data til
  // Stripe Connect. Vi går ikke gjennom Supabase-session-flyten igjen.
  if (purpose === "nin") {
    return handleNinFlow({
      userinfo,
      isNative,
      ret,
      origin: req.nextUrl.origin,
      intent,
    });
  }

  // Finn eller opprett bruker.
  let userId: string | null = null;

  // 1) Match på vipps_sub (primær — sub er stabil selv om e-post endres).
  {
    const { data } = await supabaseAdmin
      .from("profiles")
      .select("id")
      .eq("vipps_sub", userinfo.sub)
      .maybeSingle();
    if (data?.id) userId = data.id;
  }

  // 2) Match på e-post — link Vipps-sub til eksisterende konto.
  if (!userId) {
    const { data: list } = await supabaseAdmin.auth.admin.listUsers();
    const existing = list?.users?.find(
      (u) => u.email?.toLowerCase() === userinfo.email!.toLowerCase()
    );
    if (existing) userId = existing.id;
  }

  // 3) Opprett ny bruker.
  if (!userId) {
    const { data: created, error } = await supabaseAdmin.auth.admin.createUser({
      email: userinfo.email,
      email_confirm: true,
      user_metadata: {
        full_name: userinfo.name,
        phone: userinfo.phone_number,
      },
    });
    if (error || !created.user) {
      console.error("Vipps createUser failed", error);
      return redirectToLogin(req, "vipps_user_create_failed");
    }
    userId = created.user.id;
  }

  // Upsert profilen med Vipps-felter.
  await supabaseAdmin.from("profiles").upsert(
    {
      id: userId,
      vipps_sub: userinfo.sub,
      vipps_phone: userinfo.phone_number ?? null,
      ...(userinfo.name ? { full_name: userinfo.name } : {}),
    },
    { onConflict: "id" }
  );

  // Generer magic link og bruk hashed_token via /auth/callback for å sette
  // Supabase-session-cookie på vårt domene.
  const { data: linkData, error: linkErr } =
    await supabaseAdmin.auth.admin.generateLink({
      type: "magiclink",
      email: userinfo.email,
      options: {
        redirectTo: new URL(
          `/auth/callback?next=${encodeURIComponent(ret)}`,
          req.nextUrl.origin
        ).toString(),
      },
    });

  if (linkErr || !linkData?.properties) {
    console.error("Vipps generateLink failed", linkErr);
    return redirectToLogin(req, "vipps_link_failed");
  }

  if (isNative) {
    // iOS-appen veksler hashed_token via supabase.auth.verifyOTP(.magiclink).
    // Custom-scheme returnerer kontroll til ASWebAuthenticationSession.
    const hashed = linkData.properties.hashed_token;
    if (!hashed) {
      return redirectToLogin(req, "vipps_no_hashed_token");
    }
    const nativeUrl = new URL("no.tuno.app://vipps-return");
    nativeUrl.searchParams.set("token_hash", hashed);
    nativeUrl.searchParams.set("type", "magiclink");
    return NextResponse.redirect(nativeUrl.toString());
  }

  return NextResponse.redirect(linkData.properties.action_link);
}

function redirectToLogin(req: NextRequest, reason: string) {
  const url = new URL("/login", req.nextUrl.origin);
  url.searchParams.set("error", `vipps_${reason}`);
  return NextResponse.redirect(url);
}

/**
 * Fase 3 — nin-flow.
 *
 * SIKKERHETSREGLER (gjelder hele funksjonen):
 *   - userinfo.nin må ALDRI returneres til klient
 *   - userinfo.nin må ALDRI lagres i DB
 *   - userinfo.nin må ALDRI logges (heller ikke i feilhandlere)
 *   - variabler som inneholder nin scopes ut umiddelbart etter Stripe-kallet
 *   - Cache-Control: no-store på alle responser
 */
async function handleNinFlow(opts: {
  userinfo: VippsUserinfo;
  isNative: boolean;
  ret: string;
  origin: string;
  intent: string | null;
}): Promise<NextResponse> {
  const { userinfo, isNative, ret, origin, intent } = opts;
  const supabaseAdmin = createSupabase(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { autoRefreshToken: false, persistSession: false } }
  );

  // Brukerens identitet kommer fra én av to kilder:
  //   1) Native-intent (iOS): engangs-uuid pre-validert mot Bearer-token,
  //      lagret i `vipps_native_intents`. Markeres som brukt her.
  //   2) Web SSR-session: cookie-basert, brukes når intent ikke finnes.
  // Begge veier verifiserer at brukeren er pålitelig før Stripe-kallet.
  let userId: string | null = null;
  let userEmail: string | null = null;

  if (intent) {
    const { data: row } = await supabaseAdmin
      .from("vipps_native_intents")
      .select("id, user_id, purpose, expires_at, used_at")
      .eq("id", intent)
      .maybeSingle();
    if (
      !row ||
      row.purpose !== "nin" ||
      row.used_at ||
      new Date(row.expires_at).getTime() < Date.now()
    ) {
      return redirectToReturn(origin, ret, "intent_invalid", isNative);
    }
    userId = row.user_id;
    await supabaseAdmin
      .from("vipps_native_intents")
      .update({ used_at: new Date().toISOString() })
      .eq("id", row.id);

    // Hent e-post fra auth.users for matchsjekk mot Vipps.
    const { data: u } = await supabaseAdmin.auth.admin.getUserById(
      row.user_id as string
    );
    userEmail = u?.user?.email ?? null;
  } else {
    const ssr = await createSSRClient();
    const {
      data: { user },
    } = await ssr.auth.getUser();
    if (!user) {
      return redirectToReturn(origin, ret, "not_authenticated", isNative);
    }
    userId = user.id;
    userEmail = user.email ?? null;
  }

  if (
    userEmail &&
    userinfo.email &&
    userEmail.toLowerCase() !== userinfo.email.toLowerCase()
  ) {
    return redirectToReturn(origin, ret, "email_mismatch", isNative);
  }

  // Hent stripe_account_id for innlogget bruker.
  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("stripe_account_id")
    .eq("id", userId)
    .single();
  const accountId: string | null | undefined = (
    profile as { stripe_account_id?: string | null } | null
  )?.stripe_account_id;
  if (!accountId) {
    return redirectToReturn(origin, ret, "no_stripe_account", isNative);
  }

  // Bygg Stripe-payload. Address fra Vipps kan være object eller array.
  const address = pickAddress(userinfo.address);
  const dob = parseBirthdate(userinfo.birthdate);

  const individual: Stripe.AccountUpdateParams.Individual = {};
  if (userinfo.given_name) individual.first_name = userinfo.given_name;
  if (userinfo.family_name) individual.last_name = userinfo.family_name;
  if (dob) individual.dob = dob;
  if (userinfo.nin && /^\d{11}$/.test(userinfo.nin)) {
    individual.id_number = userinfo.nin;
  }
  if (userinfo.phone_number) individual.phone = userinfo.phone_number;
  if (userinfo.email) individual.email = userinfo.email;
  if (address) {
    individual.address = {
      line1: address.street_address ?? "",
      postal_code: address.postal_code ?? "",
      city: address.region ?? "",
      country: "NO",
    };
  }

  try {
    await stripe.accounts.update(accountId, { individual });
  } catch {
    // Ikke logg feilobjektet — det kan inneholde id_number i payload-ekko.
    return redirectToReturn(origin, ret, "stripe_update_failed", isNative);
  }

  return redirectToReturn(origin, ret, null, isNative);
}

function pickAddress(
  src: VippsAddress | VippsAddress[] | undefined
): VippsAddress | null {
  if (!src) return null;
  if (Array.isArray(src)) return src[0] ?? null;
  return src;
}

function parseBirthdate(
  s: string | undefined
): Stripe.AccountUpdateParams.Individual.Dob | null {
  if (!s) return null;
  // Vipps leverer YYYY-MM-DD
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) return null;
  const [, y, mo, d] = m;
  return { year: Number(y), month: Number(mo), day: Number(d) };
}

function redirectToReturn(
  origin: string,
  ret: string,
  errorReason: string | null,
  isNative: boolean
): NextResponse {
  if (isNative) {
    const u = new URL("no.tuno.app://vipps-nin-return");
    if (errorReason) u.searchParams.set("error", errorReason);
    else u.searchParams.set("status", "ok");
    return makeNoStore(NextResponse.redirect(u.toString()));
  }
  const safeReturn = ret.startsWith("/") ? ret : "/bli-utleier";
  const u = new URL(safeReturn, origin);
  if (errorReason) u.searchParams.set("vipps_nin", `error_${errorReason}`);
  else u.searchParams.set("vipps_nin", "ok");
  return makeNoStore(NextResponse.redirect(u.toString()));
}

function makeNoStore(res: NextResponse) {
  res.headers.set("Cache-Control", "no-store, no-cache, must-revalidate");
  res.headers.set("Pragma", "no-cache");
  return res;
}
