import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";
import { sendAdminAlertEmail } from "@/lib/email";
import { sendPushToAllAdmins } from "@/lib/push";
import { SITE_URL } from "@/lib/config";

export const maxDuration = 120;

/**
 * Ukentlig situasjonskontroll (mandag 06:00). Sjekker at stålportene står:
 *  - RLS-policyer på listings/storage er som forventet (ikke fjernet/endret)
 *  - Moderasjonstriggere finnes
 *  - Vaktbikkje-sweep har kjørt nylig (heartbeat)
 *  - Nødvendige env-vars er satt
 *  - Stripe-webhooks er aktive
 *  - Ingen annonse er synlig uten å være godkjent + Stripe-verifisert
 *  - Ingen admin-konto uten kjent e-post
 * Sender rapport uansett; push hvis noe er rødt.
 */

interface Check { name: string; ok: boolean; detail: string }

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);
  const checks: Check[] = [];

  // 1) Env
  for (const key of ["ANTHROPIC_API_KEY", "MODERATION_WEBHOOK_SECRET", "SUPABASE_SERVICE_ROLE_KEY", "STRIPE_WEBHOOK_SECRET", "STRIPE_CONNECT_WEBHOOK_SECRET", "RESEND_API_KEY", "GOOGLE_CLOUD_VISION_API_KEY"]) {
    checks.push({ name: `env ${key}`, ok: Boolean(process.env[key]), detail: process.env[key] ? "satt" : "MANGLER" });
  }
  checks.push({ name: "env NEXT_PUBLIC_TURNSTILE_SITE_KEY", ok: true, detail: process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY ? "captcha på" : "captcha av (ikke konfigurert)" });

  // 2) Heartbeat + nødbryter
  const { data: settings } = await supabase.from("app_settings").select("key, value");
  const get = (k: string) => settings?.find((s) => s.key === k)?.value;
  const lastSweep = typeof get("last_sweep_at") === "string" ? new Date(get("last_sweep_at") as string) : null;
  const sweepAgeMin = lastSweep ? (Date.now() - lastSweep.getTime()) / 60_000 : null;
  checks.push({ name: "moderation-sweep heartbeat", ok: sweepAgeMin !== null && sweepAgeMin < 20, detail: sweepAgeMin === null ? "aldri kjørt" : `${Math.round(sweepAgeMin)} min siden` });
  checks.push({ name: "registrering", ok: get("signups_enabled") !== false, detail: get("signups_enabled") === false ? `STENGT: ${get("signups_disabled_reason")}` : "åpen" });

  // 3) Synlige annonser som ikke burde være synlige (sett fra anon)
  const anon = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
  const { data: anonVisible } = await anon.from("listings").select("id, moderation_status, host_stripe_ready, is_active").limit(500);
  const leaks = (anonVisible ?? []).filter((l) => l.moderation_status !== "approved" || !l.host_stripe_ready || l.is_active === false);
  checks.push({ name: "RLS: kun godkjente + Stripe-verifiserte annonser synlige", ok: leaks.length === 0, detail: leaks.length ? `${leaks.length} lekkasjer: ${leaks.slice(0, 5).map((l) => l.id).join(", ")}` : `${anonVisible?.length ?? 0} synlige, alle OK` });

  // 4) Storage: anon kan ikke liste filer
  const { data: anonList } = await anon.storage.from("listing-images").list("", { limit: 5 });
  checks.push({ name: "Storage: anon kan ikke liste filer", ok: !anonList || anonList.length === 0, detail: anonList?.length ? `${anonList.length} filer eksponert` : "OK" });

  // 5) Annonser som henger i moderering
  const { count: stuck } = await supabase.from("listings").select("id", { count: "exact", head: true }).in("moderation_status", ["pending", "flagged"]).lt("created_at", new Date(Date.now() - 3 * 3600_000).toISOString());
  checks.push({ name: "annonser hengende > 3t", ok: (stuck ?? 0) === 0, detail: `${stuck ?? 0}` });

  // 6) Åpne rapporter / flagg
  const [{ count: openReports }, { count: openFlags }] = await Promise.all([
    supabase.from("reports").select("id", { count: "exact", head: true }).eq("status", "open"),
    supabase.from("content_flags").select("id", { count: "exact", head: true }).eq("status", "open"),
  ]);
  checks.push({ name: "åpne rapporter", ok: (openReports ?? 0) === 0, detail: `${openReports ?? 0}` });
  checks.push({ name: "åpne innholdsflagg", ok: (openFlags ?? 0) === 0, detail: `${openFlags ?? 0}` });

  // 7) Admins
  const { data: admins } = await supabase.from("profiles").select("id, full_name").eq("is_admin", true);
  const adminEmails: string[] = [];
  for (const a of admins ?? []) {
    const { data: u } = await supabase.auth.admin.getUserById(a.id);
    adminEmails.push(u?.user?.email ?? `${a.full_name} (ukjent e-post)`);
  }
  checks.push({ name: "admin-kontoer", ok: (admins?.length ?? 0) <= 3, detail: adminEmails.join(", ") || "ingen" });

  // 8) Stripe webhooks
  try {
    const eps = await stripe.webhookEndpoints.list({ limit: 20 });
    const enabled = eps.data.filter((e) => e.status === "enabled");
    checks.push({ name: "Stripe webhooks aktive", ok: enabled.length >= 2 && enabled.every((e) => e.url.includes("tuno.no")), detail: enabled.map((e) => `${e.url} (${e.enabled_events.length} events)`).join("; ") || "ingen" });
    const bal = await stripe.balance.retrieve();
    const nok = bal.available.find((b) => b.currency === "nok");
    checks.push({ name: "Stripe plattform-balanse", ok: (nok?.amount ?? 0) >= 0, detail: `${((nok?.amount ?? 0) / 100).toFixed(2)} kr` });
  } catch (err) {
    checks.push({ name: "Stripe", ok: false, detail: err instanceof Error ? err.message : String(err) });
  }

  // 9) Ubekreftede brukere siste 7 dager (bot-signaler)
  const { data: users } = await supabase.auth.admin.listUsers({ page: 1, perPage: 200 });
  const weekAgo = new Date(Date.now() - 7 * 86400_000).toISOString();
  const recent = (users?.users ?? []).filter((u) => u.created_at >= weekAgo);
  const unconfirmed = recent.filter((u) => !u.email_confirmed_at);
  checks.push({ name: "nye brukere siste 7 dager", ok: unconfirmed.length < Math.max(5, recent.length / 2), detail: `${recent.length} nye, ${unconfirmed.length} ubekreftet` });

  const red = checks.filter((c) => !c.ok);
  const html = `<table style="width:100%;border-collapse:collapse;font-size:13px;">${checks.map((c) => `<tr><td style="padding:6px 8px;border-bottom:1px solid #eee;">${c.ok ? "✅" : "🔴"}</td><td style="padding:6px 8px;border-bottom:1px solid #eee;font-weight:600;color:#171717;">${esc(c.name)}</td><td style="padding:6px 8px;border-bottom:1px solid #eee;color:#525252;">${esc(c.detail)}</td></tr>`).join("")}</table>`;

  await sendAdminAlertEmail(
    `${red.length ? "🔴" : "✅"} Ukentlig sikkerhetskontroll: ${red.length ? `${red.length} avvik` : "alt OK"}`,
    html,
    `${SITE_URL}/admin/moderering`,
  );
  if (red.length) {
    await sendPushToAllAdmins("Sikkerhetskontroll: avvik", red.map((c) => c.name).join(" · "), { type: "admin_moderation" });
  }

  return NextResponse.json({ ok: red.length === 0, checks });
}

function esc(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
}
