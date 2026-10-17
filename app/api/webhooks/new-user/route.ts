import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { sendNewUserAdminEmail } from "@/lib/email";

export const maxDuration = 30;

/**
 * Kalles av Postgres-triggeren på profiles-insert (pg_net), samme mønster
 * som moderering-webhookene. Varsler admin om nye brukere uansett om
 * registreringen skjedde på web eller i appen.
 */
export async function POST(request: NextRequest) {
  const auth = request.headers.get("authorization");
  const allowed = [process.env.MODERATION_WEBHOOK_SECRET, process.env.CRON_SECRET]
    .filter((s): s is string => Boolean(s))
    .map((s) => `Bearer ${s}`);
  if (!auth || !allowed.includes(auth)) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let body: { userId?: string; email?: string; fullName?: string } = {};
  try {
    body = await request.json();
  } catch {
    // ignore
  }
  if (typeof body.userId !== "string") {
    return NextResponse.json({ error: "userId required" }, { status: 400 });
  }

  // Totaltelling er kuriosa i e-posten; feiler den, sender vi uten.
  let totalUsers: number | null = null;
  try {
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
    );
    const { count } = await supabase
      .from("profiles")
      .select("id", { count: "exact", head: true });
    totalUsers = count;
  } catch {
    // ignore
  }

  await sendNewUserAdminEmail({
    fullName: typeof body.fullName === "string" ? body.fullName : null,
    email: typeof body.email === "string" ? body.email : null,
    totalUsers,
  });
  return NextResponse.json({ ok: true });
}
