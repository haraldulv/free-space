import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { setPayoutScheduleDaily } from "@/lib/stripe";

/**
 * Engangsendpoint: setter payout schedule fra "manual" til "daily" på alle
 * eksisterende Connect-kontoer. Sikret med CRON_SECRET (samme som cronjobs).
 *
 * Trygg å kjøre flere ganger (idempotent — Stripe godtar samme verdi).
 */
export async function POST(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
  );

  const { data: profiles, error } = await supabase
    .from("profiles")
    .select("id, stripe_account_id")
    .not("stripe_account_id", "is", null);

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  const results: { accountId: string; status: "ok" | "failed"; error?: string }[] = [];
  for (const p of profiles || []) {
    const accountId = p.stripe_account_id as string;
    try {
      await setPayoutScheduleDaily(accountId);
      results.push({ accountId, status: "ok" });
    } catch (err) {
      results.push({
        accountId,
        status: "failed",
        error: err instanceof Error ? err.message : "Unknown",
      });
    }
  }

  const ok = results.filter((r) => r.status === "ok").length;
  const failed = results.length - ok;
  return NextResponse.json({ updated: ok, failed, results });
}
