import { NextRequest, NextResponse } from "next/server";
import { moderateListing } from "@/lib/moderation";

export const maxDuration = 120;

/**
 * Kalles av Postgres-triggeren `listings_moderation_webhook` (pg_net) når
 * en annonse blir `pending`. Secret ligger i Supabase Vault
 * (`moderation_webhook_secret`) og i Vercel env `MODERATION_WEBHOOK_SECRET`.
 * CRON_SECRET aksepteres også så sweep-cronen kan gjenbruke ruten.
 */
export async function POST(request: NextRequest) {
  const auth = request.headers.get("authorization");
  const allowed = [process.env.MODERATION_WEBHOOK_SECRET, process.env.CRON_SECRET]
    .filter((s): s is string => Boolean(s))
    .map((s) => `Bearer ${s}`);

  if (!auth || !allowed.includes(auth)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let listingId: string | undefined;
  try {
    const body = await request.json();
    listingId = typeof body?.listingId === "string" ? body.listingId : undefined;
  } catch {
    // ignore
  }
  if (!listingId) {
    return NextResponse.json({ error: "listingId required" }, { status: 400 });
  }

  const result = await moderateListing(listingId);
  return NextResponse.json({ ok: true, skipped: result === null, verdict: result?.verdict ?? null });
}
