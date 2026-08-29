import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { Resend } from "resend";
import { ADMIN_EMAILS, SITE_URL } from "@/lib/config";
import { sendPushToAllAdmins } from "@/lib/push";

export const maxDuration = 120;

/**
 * Vaktbikkje: oppsummerer siste 12 timer med sikkerhetsrelevant aktivitet
 * og sender e-post til admins (07:00 alltid, 19:00 kun ved aktivitet).
 *
 * Dekker: nye brukere, nye/endrede annonser med moderasjonsstatus, nye
 * Stripe-onboardinger, annonser som henger i pending/flagged, feilede
 * utbetalinger/overføringer, og enkle misbruks-signaler (mange signups
 * fra samme e-postdomene, bruker med mange annonser på kort tid).
 */

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);
const resend = new Resend(process.env.RESEND_API_KEY);

function esc(s: unknown): string {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
}
function fmt(iso: string | null | undefined): string {
  if (!iso) return "";
  return new Date(iso).toLocaleString("nb-NO", { timeZone: "Europe/Oslo", day: "2-digit", month: "short", hour: "2-digit", minute: "2-digit" });
}
function section(title: string, rows: string[], empty = "Ingen"): string {
  const body = rows.length
    ? `<ul style="margin:6px 0 0;padding-left:18px;font-size:13px;line-height:1.6;color:#404040;">${rows.map((r) => `<li>${r}</li>`).join("")}</ul>`
    : `<p style="margin:4px 0 0;font-size:13px;color:#a3a3a3;">${empty}</p>`;
  return `<div style="margin-top:18px;"><p style="margin:0;font-size:12px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:#737373;">${title}</p>${body}</div>`;
}

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const quiet = request.nextUrl.searchParams.get("quiet") === "1";
  const hours = Number(request.nextUrl.searchParams.get("hours") ?? "12");
  const since = new Date(Date.now() - hours * 3600_000).toISOString();

  // --- Nye brukere (auth.users via admin API; profiles gir navn) ---
  const { data: usersPage } = await supabase.auth.admin.listUsers({ page: 1, perPage: 200 });
  const newUsers = (usersPage?.users ?? [])
    .filter((u) => u.created_at >= since)
    .sort((a, b) => (a.created_at < b.created_at ? 1 : -1));
  const unconfirmedOld = (usersPage?.users ?? []).filter(
    (u) => !u.email_confirmed_at && u.created_at < since && u.created_at >= new Date(Date.now() - 7 * 86400_000).toISOString(),
  );

  const [{ data: listingsNew }, { data: listingsStuck }, { data: newHosts }, { data: failedTransfers }, { data: bookingsNew }] = await Promise.all([
    supabase
      .from("listings")
      .select("id, title, city, created_at, moderation_status, moderation_reason, host_stripe_ready, host:host_id(full_name)")
      .or(`created_at.gte.${since},moderated_at.gte.${since}`)
      .order("created_at", { ascending: false })
      .limit(50),
    supabase
      .from("listings")
      .select("id, title, created_at, moderation_status, moderation_reason, host:host_id(full_name)")
      .in("moderation_status", ["pending", "flagged"])
      .lt("created_at", new Date(Date.now() - 3600_000).toISOString())
      .order("created_at", { ascending: true })
      .limit(50),
    supabase
      .from("profiles")
      .select("id, full_name, stripe_account_id, stripe_onboarding_complete, created_at")
      .not("stripe_account_id", "is", null)
      .gte("created_at", since)
      .limit(50),
    supabase
      .from("bookings")
      .select("id, total_price, transfer_status, transfer_error, transfer_failed_at, listing:listing_id(title)")
      .or(`transfer_failed_at.gte.${since},and(transfer_status.eq.failed,transfer_failed_at.is.null)`)
      .limit(20),
    supabase
      .from("bookings")
      .select("id, total_price, status, payment_status, created_at, listing:listing_id(title), guest:user_id(full_name)")
      .gte("created_at", since)
      .order("created_at", { ascending: false })
      .limit(50),
  ]);

  // --- Misbruks-signaler ---
  const domainCounts = new Map<string, number>();
  newUsers.forEach((u) => {
    const d = (u.email ?? "").split("@")[1]?.toLowerCase();
    if (d) domainCounts.set(d, (domainCounts.get(d) ?? 0) + 1);
  });
  const suspiciousDomains = Array.from(domainCounts.entries()).filter(([d, n]) => n >= 3 && !["gmail.com", "hotmail.com", "icloud.com", "outlook.com", "privaterelay.appleid.com"].includes(d));

  const hostListingCounts = new Map<string, number>();
  (listingsNew ?? []).forEach((l) => {
    const name = (l.host as unknown as { full_name: string } | null)?.full_name ?? "?";
    hostListingCounts.set(name, (hostListingCounts.get(name) ?? 0) + 1);
  });
  const bulkHosts = Array.from(hostListingCounts.entries()).filter(([, n]) => n >= 3);

  const flagged = (listingsNew ?? []).filter((l) => l.moderation_status === "flagged");
  const signals: string[] = [
    ...suspiciousDomains.map(([d, n]) => `${n} nye brukere fra <b>${esc(d)}</b> på ${hours} timer`),
    ...bulkHosts.map(([name, n]) => `<b>${esc(name)}</b> opprettet ${n} annonser på ${hours} timer`),
    ...(unconfirmedOld.length >= 5 ? [`${unconfirmedOld.length} ubekreftede kontoer eldre enn ${hours}t (mulig bot-signup)`] : []),
  ];

  const activity =
    newUsers.length + (listingsNew?.length ?? 0) + (newHosts?.length ?? 0) + (failedTransfers?.length ?? 0) + (bookingsNew?.length ?? 0) + (listingsStuck?.length ?? 0) + signals.length;

  if (quiet && activity === 0) {
    return NextResponse.json({ sent: false, reason: "quiet, no activity" });
  }

  const urgent = flagged.length > 0 || (listingsStuck?.length ?? 0) > 0 || (failedTransfers?.length ?? 0) > 0 || signals.length > 0;

  const html = `<!DOCTYPE html><html lang="nb"><body style="margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
<div style="max-width:600px;margin:0 auto;padding:24px 16px;">
  <div style="background:#fff;border-radius:12px;padding:24px;border:1px solid #e5e5e5;">
    <h1 style="margin:0;font-size:18px;color:#171717;">Tuno vaktbikkje · siste ${hours} timer</h1>
    <p style="margin:4px 0 0;font-size:12px;color:#a3a3a3;">${fmt(new Date().toISOString())} · ${urgent ? "<span style=\"color:#dc2626;font-weight:700;\">trenger et blikk</span>" : "alt rolig"}</p>

    ${signals.length ? section("⚠️ Signaler", signals) : ""}

    ${section(`Flagget / hengende annonser (${(listingsStuck?.length ?? 0) + flagged.length})`, [
      ...flagged.map((l) => `<b>${esc(l.title)}</b> · ${esc((l.host as unknown as { full_name: string } | null)?.full_name)} · <span style="color:#dc2626">${esc(l.moderation_reason ?? "flagget")}</span> · <a href="${SITE_URL}/admin/moderering?listing=${l.id}">åpne</a>`),
      ...(listingsStuck ?? []).filter((l) => !flagged.some((f) => f.id === l.id)).map((l) => `<b>${esc(l.title)}</b> · ${esc(l.moderation_status)} siden ${fmt(l.created_at)} · <a href="${SITE_URL}/admin/moderering?listing=${l.id}">åpne</a>`),
    ], "Ingen, alt er behandlet")}

    ${section(`Nye brukere (${newUsers.length})`, newUsers.map((u) => `${esc(u.email)} · ${esc(u.app_metadata?.provider ?? "email")} · ${u.email_confirmed_at ? "bekreftet" : "<span style=\"color:#b45309\">ubekreftet</span>"} · ${fmt(u.created_at)}`))}

    ${section(`Nye / endrede annonser (${listingsNew?.length ?? 0})`, (listingsNew ?? []).map((l) => `<b>${esc(l.title)}</b> · ${esc(l.city)} · ${esc((l.host as unknown as { full_name: string } | null)?.full_name)} · ${esc(l.moderation_status)}${l.host_stripe_ready ? "" : " · Stripe ikke verifisert"} · ${fmt(l.created_at)}`))}

    ${section(`Nye utleiere (Stripe-onboarding startet) (${newHosts?.length ?? 0})`, (newHosts ?? []).map((h) => `${esc(h.full_name)} · ${h.stripe_onboarding_complete ? "verifisert" : "ikke ferdig"} · ${esc(h.stripe_account_id)}`))}

    ${section(`Nye bookinger (${bookingsNew?.length ?? 0})`, (bookingsNew ?? []).map((b) => `${esc((b.listing as unknown as { title: string } | null)?.title)} · ${esc((b.guest as unknown as { full_name: string } | null)?.full_name)} · ${b.total_price} kr · ${esc(b.status)}/${esc(b.payment_status)} · ${fmt(b.created_at)}`))}

    ${section(`Feilede utbetalinger (${failedTransfers?.length ?? 0})`, (failedTransfers ?? []).map((b) => `${esc((b.listing as unknown as { title: string } | null)?.title)} · ${b.total_price} kr · <span style="color:#dc2626">${esc(b.transfer_error ?? "failed")}</span>`))}

    <p style="margin-top:24px;font-size:12px;color:#a3a3a3;"><a href="${SITE_URL}/admin/moderering" style="color:#46C185;">Moderering</a> · <a href="${SITE_URL}/admin" style="color:#46C185;">Admin</a></p>
  </div>
</div></body></html>`;

  await resend.emails.send({
    from: "Tuno vaktbikkje <noreply@tuno.no>",
    to: ADMIN_EMAILS,
    subject: `${urgent ? "⚠️ " : ""}Vaktbikkje: ${newUsers.length} brukere, ${listingsNew?.length ?? 0} annonser, ${flagged.length + (listingsStuck?.length ?? 0)} å se på`,
    html,
  });

  if (urgent) {
    await sendPushToAllAdmins(
      "Vaktbikkje: trenger et blikk",
      `${flagged.length} flagget · ${listingsStuck?.length ?? 0} hengende · ${signals.length} signaler`,
      { type: "admin_moderation" },
    );
  }

  return NextResponse.json({ sent: true, urgent, newUsers: newUsers.length, listings: listingsNew?.length ?? 0, stuck: listingsStuck?.length ?? 0, signals });
}
