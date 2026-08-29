import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { moderateListing } from "@/lib/moderation";

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

  return NextResponse.json({ processed: Object.keys(results).length, results });
}
