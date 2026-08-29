import { NextRequest, NextResponse } from "next/server";
import { moderateText } from "@/lib/moderation";

export const maxDuration = 60;

/**
 * Kalles av Postgres-triggerne på messages/reviews (pg_net). Asynkron:
 * innholdet er allerede levert; vi flagger og varsler admin ved treff.
 */
export async function POST(request: NextRequest) {
  const auth = request.headers.get("authorization");
  const allowed = [process.env.MODERATION_WEBHOOK_SECRET, process.env.CRON_SECRET]
    .filter((s): s is string => Boolean(s))
    .map((s) => `Bearer ${s}`);
  if (!auth || !allowed.includes(auth)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let body: { type?: string; id?: string } = {};
  try {
    body = await request.json();
  } catch {
    // ignore
  }
  if ((body.type !== "message" && body.type !== "review") || typeof body.id !== "string") {
    return NextResponse.json({ error: "type + id required" }, { status: 400 });
  }

  const result = await moderateText({ type: body.type, id: body.id });
  return NextResponse.json({ ok: true, result });
}
