import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { moderateListing, setListingModeration } from "@/lib/moderation";
import { FLAGGED_AUTO_REJECT_HOURS, SIGNUP_BURST_LIMIT_PER_10_MIN, SITE_URL } from "@/lib/config";
import { sendPushToAllAdmins } from "@/lib/push";
import { sendAdminAlertEmail } from "@/lib/email";

export const maxDuration = 300;

/**
 * Sikkerhetsnett hvert 5. minutt: annonser som fortsatt er `pending` og
 * ikke har fått en AI-vurdering (f.eks. fordi pg_net-webhooken ikke nådde
 * fram) plukkes opp her. Annonser som er pending pga. manglende
 * ANTHROPIC_API_KEY får `moderation_ai.error` og prøves igjen.
 */
export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );

  const cutoff = new Date(Date.now() - 60_000).toISOString();
  const { data, error } = await supabase
    .from("listings")
    .select("id")
    .eq("moderation_status", "pending")
    .lte("created_at", cutoff)
    .order("created_at", { ascending: true })
    .limit(10);

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  const results: Record<string, string> = {};
  for (const row of data ?? []) {
    const r = await moderateListing(row.id);
    results[row.id] = r?.verdict ?? "skipped";
  }

  // Flaggede annonser som ingen admin har tatt stilling til på 48 timer
  // avvises automatisk (fail closed). Hosten får beskjed med AI-begrunnelsen
  // og kan kontakte support.
  const staleCutoff = new Date(Date.now() - FLAGGED_AUTO_REJECT_HOURS * 3600_000).toISOString();
  const { data: stale } = await supabase
    .from("listings")
    .select("id, moderation_reason")
    .eq("moderation_status", "flagged")
    .lte("moderated_at", staleCutoff)
    .limit(10);
  const autoRejected: string[] = [];
  for (const row of stale ?? []) {
    try {
      await setListingModeration(
        row.id,
        "rejected",
        null,
        row.moderation_reason
          ? `Automatisk avvist etter ${FLAGGED_AUTO_REJECT_HOURS} timer: ${row.moderation_reason}`
          : `Automatisk avvist etter ${FLAGGED_AUTO_REJECT_HOURS} timer uten godkjenning.`,
      );
      autoRejected.push(row.id);
    } catch (err) {
      console.error("[Moderation] auto-reject failed", row.id, err);
    }
  }

  // Nødbryter: unormal signup-hastighet → steng registrering + varsle.
  let signupsClosed = false;
  const { count: recentSignups } = await supabase
    .from("profiles")
    .select("id", { count: "exact", head: true })
    .gte("created_at", new Date(Date.now() - 10 * 60_000).toISOString());
  if ((recentSignups ?? 0) > SIGNUP_BURST_LIMIT_PER_10_MIN) {
    const { data: setting } = await supabase.from("app_settings").select("value").eq("key", "signups_enabled").maybeSingle();
    if (setting?.value !== false) {
      const reason = `Automatisk stengt ${new Date().toISOString()}: ${recentSignups} nye brukere på 10 minutter (grense ${SIGNUP_BURST_LIMIT_PER_10_MIN}).`;
      await Promise.all([
        supabase.from("app_settings").update({ value: false, updated_at: new Date().toISOString() }).eq("key", "signups_enabled"),
        supabase.from("app_settings").update({ value: reason, updated_at: new Date().toISOString() }).eq("key", "signups_disabled_reason"),
      ]);
      signupsClosed = true;
      const title = "🚨 Registrering stengt automatisk";
      await Promise.all([
        sendPushToAllAdmins(title, reason, { type: "admin_moderation" }),
        sendAdminAlertEmail(title, `<p style="font-size:14px;color:#404040;">${reason}</p><p style="font-size:14px;color:#404040;">Nye registreringer avvises på databasenivå til du åpner igjen i admin.</p>`, `${SITE_URL}/admin/moderering`).catch(() => {}),
      ]);
    }
  }

  // Heartbeat for ukentlig helsesjekk
  await supabase.from("app_settings").update({ value: new Date().toISOString(), updated_at: new Date().toISOString() }).eq("key", "last_sweep_at");

  return NextResponse.json({ processed: Object.keys(results).length, results, autoRejected, recentSignups, signupsClosed });
}
