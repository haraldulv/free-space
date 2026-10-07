"use server";

import { createClient as createServiceClient } from "@supabase/supabase-js";
import { sendCalculatorLeadEmail } from "@/lib/email";
import { sendPushToAllAdmins } from "@/lib/push";
import { getNotifyAdminIds } from "@/lib/admins";

function getServiceClient() {
  return createServiceClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );
}

/**
 * Lead fra kalkulatorsiden /tjen («Vi ringer deg»). Lander som outreach-lead
 * i samme system som ringerunden, så oppfølging skjer i /admin/outreach med
 * follow_up-cron og det hele. Admin varsles med e-post, push og in-app.
 */
export async function submitEarnLeadAction(input: {
  name: string;
  phone: string;
  /** Honeypot; mennesker lar den stå tom. */
  website?: string;
}): Promise<{ error?: string }> {
  const name = (input.name ?? "").trim();
  const phone = (input.phone ?? "").trim();

  // Honeypot: lat som alt gikk bra, uten å lagre noe.
  if (input.website && input.website.trim().length > 0) {
    return {};
  }

  if (name.length < 2 || name.length > 80) {
    return { error: "invalid_name" };
  }
  const phoneDigits = phone.replace(/[^\d+]/g, "");
  if (!/^\+?\d{8,15}$/.test(phoneDigits)) {
    return { error: "invalid_phone" };
  }

  const supabase = getServiceClient();

  // Samme telefonnummer siste døgn = duplikat; svar vennlig uten ny rad.
  const { data: existing } = await supabase
    .from("outreach_targets")
    .select("id")
    .eq("phone", phoneDigits)
    .gte("created_at", new Date(Date.now() - 24 * 3600_000).toISOString())
    .limit(1);
  if (existing && existing.length > 0) {
    return {};
  }

  const followUp = new Date();
  followUp.setDate(followUp.getDate() + 1);

  const { error } = await supabase.from("outreach_targets").insert({
    place_id: `lead:${crypto.randomUUID()}`,
    name,
    contact_person: name,
    phone: phoneDigits,
    category: "parkering",
    area: "asker",
    statuses: ["interested"],
    notes: "Lead fra tuno.no/tjen (kalkulatoren). Vil bli ringt.",
    follow_up_at: followUp.toISOString(),
  });
  if (error) {
    console.error("[tjen] lead insert failed:", error.message);
    return { error: "insert_failed" };
  }

  const title = "Ny lead fra kalkulatoren";
  const body = `${name} (${phoneDigits}) vil bli ringt om utleie i Asker.`;
  await Promise.all([
    sendCalculatorLeadEmail({ name, phone: phoneDigits }).catch((err) =>
      console.error("[tjen] lead email failed:", err),
    ),
    sendPushToAllAdmins(title, body, { type: "admin_moderation" }),
    (async () => {
      const ids = await getNotifyAdminIds();
      if (!ids.length) return;
      await supabase.from("notifications").insert(
        ids.map((id) => ({ user_id: id, type: "admin_moderation", title, body, metadata: { source: "tjen" } })),
      );
    })().catch((err) => console.error("[tjen] lead notification failed:", err)),
  ]);

  return {};
}
