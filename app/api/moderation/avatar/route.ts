import { NextRequest, NextResponse } from "next/server";
import { moderateAvatar } from "@/lib/moderation";

export const maxDuration = 60;

/**
 * Kalles av Postgres-triggeren på profiles.avatar_url (pg_net), så sjekken
 * kjører uansett hvilken klient/versjon som byttet bildet.
 */
export async function POST(request: NextRequest) {
  const auth = request.headers.get("authorization");
  const allowed = [process.env.MODERATION_WEBHOOK_SECRET, process.env.CRON_SECRET]
    .filter((s): s is string => Boolean(s))
    .map((s) => `Bearer ${s}`);
  if (!auth || !allowed.includes(auth)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  let body: { userId?: string; avatarUrl?: string } = {};
  try {
    body = await request.json();
  } catch {
    // ignore
  }
  if (typeof body.userId !== "string" || typeof body.avatarUrl !== "string") {
    return NextResponse.json({ error: "userId + avatarUrl required" }, { status: 400 });
  }
  const result = await moderateAvatar(body.userId, body.avatarUrl);
  return NextResponse.json({ ok: true, ...result });
}
