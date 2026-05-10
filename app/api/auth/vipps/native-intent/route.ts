import { NextRequest, NextResponse } from "next/server";
import { createClient as createSupabase } from "@supabase/supabase-js";

/**
 * Native-intent-bro for iOS Vipps-flyt (Fase 3 / nin).
 *
 * iOS-appen åpner Vipps via ASWebAuthenticationSession som ikke deler
 * Supabase-session-cookies med web. For å verifisere at den som starter
 * nin-flyten faktisk er den innloggede brukeren i appen, oppretter vi
 * et engangs-intent her: appen kaller med Bearer-token, vi validerer
 * sesjonen, lagrer (user_id, purpose) i `vipps_native_intents`, og
 * returnerer en uuid som appen sender med inn i /start?intent=<id>.
 *
 * Callback-ruten leser intent fra cookie, slår opp user_id, og
 * bruker den i stedet for SSR-session som ikke er tilgjengelig fra
 * native context.
 */
export async function POST(req: NextRequest) {
  const auth = req.headers.get("authorization");
  if (!auth?.toLowerCase().startsWith("bearer ")) {
    return NextResponse.json({ error: "missing_bearer" }, { status: 401 });
  }
  const accessToken = auth.slice(7).trim();
  if (!accessToken) {
    return NextResponse.json({ error: "missing_bearer" }, { status: 401 });
  }

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
  const admin = createSupabase(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  // Validér access-token mot Supabase auth-endepunktet.
  const { data: userData, error: userErr } =
    await admin.auth.getUser(accessToken);
  if (userErr || !userData?.user) {
    return NextResponse.json({ error: "invalid_token" }, { status: 401 });
  }

  let purpose: string;
  try {
    const body = (await req.json()) as { purpose?: string };
    purpose = body.purpose === "nin" ? "nin" : "login";
  } catch {
    purpose = "nin";
  }

  const { data, error } = await admin
    .from("vipps_native_intents")
    .insert({ user_id: userData.user.id, purpose })
    .select("id")
    .single();

  if (error || !data) {
    return NextResponse.json({ error: "intent_failed" }, { status: 500 });
  }

  return NextResponse.json(
    { intent: data.id },
    { headers: { "Cache-Control": "no-store" } }
  );
}
