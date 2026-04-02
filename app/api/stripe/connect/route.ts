import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createConnectAccount, createAccountLink } from "@/lib/stripe";

export async function POST() {
  try {
    const supabase = await createClient();
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      return NextResponse.json({ error: "Ikke innlogget" }, { status: 401 });
    }

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

    // Create onboarding link
    const origin = process.env.NEXT_PUBLIC_SITE_URL || "https://tuno.no";
    const url = await createAccountLink(
      accountId,
      `${origin}/api/stripe/connect/callback`,
      `${origin}/api/stripe/connect/refresh`,
    );

    return NextResponse.json({ url });
  } catch (err) {
    console.error("Connect route error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
