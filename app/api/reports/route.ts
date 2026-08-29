import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import { sendAdminAlertEmail } from "@/lib/email";
import { sendPushToAllAdmins } from "@/lib/push";
import { SITE_URL } from "@/lib/config";

const TARGET_TYPES = ["listing", "user", "conversation", "review"] as const;
const REASONS = ["scam", "inappropriate", "harassment", "fake", "spam", "other"] as const;

export const REPORT_REASON_LABELS: Record<(typeof REASONS)[number], string> = {
  scam: "Svindel eller betaling utenom Tuno",
  inappropriate: "Upassende innhold",
  harassment: "Trakassering eller trusler",
  fake: "Falsk annonse eller profil",
  spam: "Spam",
  other: "Annet",
};

/**
 * Brukerrapport (web via cookie, iOS via Bearer). Lagres med service-rolle
 * (rate-limit-trigger i DB), admin varsles med e-post + push + in-app.
 */
export async function POST(req: NextRequest) {
  const supabase = await createClient();
  const bearer = req.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  const { data: { user } } = bearer ? await supabase.auth.getUser(bearer) : await supabase.auth.getUser();
  if (!user) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  let body: { targetType?: string; targetId?: string; reason?: string; details?: string } = {};
  try {
    body = await req.json();
  } catch {
    // ignore
  }
  const targetType = TARGET_TYPES.find((t) => t === body.targetType);
  const reason = REASONS.find((r) => r === body.reason);
  const targetId = typeof body.targetId === "string" ? body.targetId.slice(0, 100) : "";
  const details = typeof body.details === "string" ? body.details.slice(0, 2000).trim() : "";
  if (!targetType || !reason || !targetId) {
    return NextResponse.json({ error: "targetType, targetId og reason er påkrevd" }, { status: 400 });
  }
  if (targetType === "user" && targetId === user.id) {
    return NextResponse.json({ error: "Du kan ikke rapportere deg selv" }, { status: 400 });
  }

  const service = createServiceClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);

  const { data: report, error } = await service
    .from("reports")
    .insert({ reporter_id: user.id, target_type: targetType, target_id: targetId, reason, details: details || null })
    .select("id")
    .single();
  if (error) {
    const msg = error.message.includes("For mange rapporter") ? "For mange rapporter. Prøv igjen i morgen." : error.message;
    return NextResponse.json({ error: msg }, { status: 400 });
  }

  // Kontekst til varselet
  const { data: reporter } = await service.from("profiles").select("full_name").eq("id", user.id).maybeSingle();
  let targetLabel = targetId;
  if (targetType === "listing") {
    const { data } = await service.from("listings").select("title").eq("id", targetId).maybeSingle();
    targetLabel = data?.title ?? targetId;
  } else if (targetType === "user") {
    const { data } = await service.from("profiles").select("full_name").eq("id", targetId).maybeSingle();
    targetLabel = data?.full_name ?? targetId;
  }

  const title = `Rapport: ${REPORT_REASON_LABELS[reason]}`;
  const summary = `${reporter?.full_name ?? "Bruker"} rapporterte ${targetType} «${targetLabel}»${details ? `: ${details.slice(0, 140)}` : ""}`;
  const adminUrl = `${SITE_URL}/admin/moderering?tab=reports&report=${report.id}`;

  const { data: admins } = await service.from("profiles").select("id").eq("is_admin", true);
  await Promise.all([
    admins?.length
      ? service.from("notifications").insert(admins.map((a) => ({ user_id: a.id, type: "admin_report", title, body: summary, metadata: { reportId: report.id, targetType, targetId } })))
      : Promise.resolve(),
    sendPushToAllAdmins(title, summary, { type: "admin_report", reportId: report.id }),
    sendAdminAlertEmail(
      title,
      `<p style="font-size:14px;color:#404040;">${escape(summary)}</p>${details ? `<blockquote style="margin:12px 0;padding:12px 16px;background:#fafafa;border-left:3px solid #46C185;color:#404040;font-size:14px;white-space:pre-wrap;">${escape(details)}</blockquote>` : ""}`,
      adminUrl,
    ).catch((err) => console.error("[Reports] email failed:", err)),
  ]);

  return NextResponse.json({ ok: true, id: report.id });
}

function escape(s: string): string {
  return s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c] as string));
}
