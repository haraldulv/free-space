import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import { createConnectAccount, createAccountLink } from "@/lib/stripe";

export async function POST(request: NextRequest) {
  try {
    const body = await request.json().catch(() => ({}));
    const platform = body.platform as string | undefined;

    // Authenticate — Bearer token (native app) or cookies (web)
    let userId: string;
    let userEmail: string;

    const authHeader = request.headers.get("authorization");
    if (authHeader?.startsWith("Bearer ")) {
      const supabase = createServiceClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.SUPABASE_SERVICE_ROLE_KEY!
      );
      const { data: { user }, error } = await supabase.auth.getUser(authHeader.slice(7));
      if (error || !user) {
        return NextResponse.json({ error: "Ugyldig token" }, { status: 401 });
      }
      userId = user.id;
      userEmail = user.email || "";
    } else {
      const supabase = await createClient();
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) {
        return NextResponse.json({ error: "Ikke innlogget" }, { status: 401 });
      }
      userId = user.id;
      userEmail = user.email || "";
    }

    // Use service client for DB operations
    const db = createServiceClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    // Check if already has an account
    const { data: profile } = await db
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", userId)
      .single();

    let accountId = profile?.stripe_account_id;

    if (!accountId) {
      // Create new Express account
      const account = await createConnectAccount(userEmail);
      accountId = account.id;

      await db
        .from("profiles")
        .update({ stripe_account_id: accountId })
        .eq("id", userId);
    }

    // Create onboarding link — use app callback URL for native
    const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";
    const callbackUrl = platform === "ios"
      ? `${origin}/api/stripe/connect/callback?platform=ios`
      : `${origin}/api/stripe/connect/callback`;
    const refreshUrl = platform === "ios"
      ? `${origin}/api/stripe/connect/refresh?platform=ios`
      : `${origin}/api/stripe/connect/refresh`;

    const url = await createAccountLink(accountId, callbackUrl, refreshUrl);

    return NextResponse.json({ url });
  } catch (err) {
    console.error("Connect route error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
