import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createConnectAccount, createAccountLink } from "@/lib/stripe";

export async function POST(request: Request) {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: "Ikke innlogget" }, { status: 401 });
    }

    // Check if request comes from native app
    const body = await request.json().catch(() => ({}));
    const platform = body.platform as string | undefined;

    // Check if already has an account
    const { data: profile } = await supabase
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", user.id)
      .single();

    let accountId = profile?.stripe_account_id;

    if (!accountId) {
      // Create new Express account
      const account = await createConnectAccount(user.email || "");
      accountId = account.id;

      await supabase
        .from("profiles")
        .update({ stripe_account_id: accountId })
        .eq("id", user.id);
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
