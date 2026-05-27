import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { Resend } from "resend";

/**
 * Daglig: finn outreach_targets der follow_up_at er passert og status ikke er
 * en av endetilstandene (responded, declined, onboarded). Send én oppsummert
 * e-post til harald@tuno.no.
 */

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!,
);

const resend = new Resend(process.env.RESEND_API_KEY);

const TERMINAL_STATUSES = ["responded", "declined", "onboarded"];

export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const nowIso = new Date().toISOString();

  const { data, error } = await supabase
    .from("outreach_targets")
    .select("id, name, statuses, category, area, phone, email, follow_up_at, notes")
    .lte("follow_up_at", nowIso)
    .not("statuses", "ov", `{${TERMINAL_STATUSES.join(",")}}`)
    .order("follow_up_at", { ascending: true })
    .limit(200);

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  const overdue = data ?? [];
  if (overdue.length === 0) {
    return NextResponse.json({ overdue: 0 });
  }

  const rows = overdue.map((t) => `
    <tr>
      <td style="padding:6px 8px;font-size:13px;color:#171717;border-bottom:1px solid #f5f5f5;">${t.name}</td>
      <td style="padding:6px 8px;font-size:12px;color:#525252;border-bottom:1px solid #f5f5f5;">${(t.statuses ?? []).join(", ")}</td>
      <td style="padding:6px 8px;font-size:12px;color:#525252;border-bottom:1px solid #f5f5f5;">${t.phone ?? ""}</td>
      <td style="padding:6px 8px;font-size:12px;color:#525252;border-bottom:1px solid #f5f5f5;">${t.email ?? ""}</td>
      <td style="padding:6px 8px;font-size:11px;color:#737373;border-bottom:1px solid #f5f5f5;">${t.notes ?? ""}</td>
    </tr>`).join("");

  await resend.emails.send({
    from: "Tuno <noreply@tuno.no>",
    to: "harald@tuno.no",
    subject: `Outreach: ${overdue.length} aktører klar for oppfølging`,
    html: `
      <div style="font-family:-apple-system,sans-serif;max-width:720px;margin:0 auto;padding:24px;">
        <h2 style="font-size:18px;color:#171717;">Klar for oppfølging</h2>
        <p style="color:#525252;font-size:14px;">${overdue.length} aktører har planlagt oppfølging som er forfalt.</p>
        <table style="width:100%;border-collapse:collapse;margin-top:12px;">
          <thead>
            <tr style="background:#fafafa;">
              <th style="padding:8px;text-align:left;font-size:11px;text-transform:uppercase;color:#737373;">Navn</th>
              <th style="padding:8px;text-align:left;font-size:11px;text-transform:uppercase;color:#737373;">Status</th>
              <th style="padding:8px;text-align:left;font-size:11px;text-transform:uppercase;color:#737373;">Telefon</th>
              <th style="padding:8px;text-align:left;font-size:11px;text-transform:uppercase;color:#737373;">E-post</th>
              <th style="padding:8px;text-align:left;font-size:11px;text-transform:uppercase;color:#737373;">Notater</th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
        <p style="margin-top:16px;"><a href="https://tuno.no/admin/outreach" style="color:#46C185;">Åpne outreach-admin</a></p>
      </div>
    `,
  });

  return NextResponse.json({ overdue: overdue.length });
}
