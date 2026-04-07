import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import {
  createConnectAccount,
  createAccountSession,
} from "@/lib/stripe";

export async function POST(request: NextRequest) {
  try {
    await request.json().catch(() => ({}));

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

    // Check if already has an account, and pull full_name for prefill
    const { data: profile } = await db
      .from("profiles")
      .select("stripe_account_id, full_name")
      .eq("id", userId)
      .single();

    let accountId = profile?.stripe_account_id as string | null | undefined;

    if (!accountId) {
      // Create new Express account with aggressive prefill
      const account = await createConnectAccount({
        email: userEmail,
        fullName: profile?.full_name ?? null,
      });
      accountId = account.id;

      await db
        .from("profiles")
        .update({ stripe_account_id: accountId })
        .eq("id", userId);
    }

    // Embedded onboarding (iOS via StripeConnect SDK, web via @stripe/react-connect-js)
    const publishableKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY;
    if (!publishableKey) {
      return NextResponse.json(
        { error: "Stripe publishable key not configured" },
        { status: 500 },
      );
    }
    const session = await createAccountSession(accountId);
    return NextResponse.json({
      accountId,
      clientSecret: session.client_secret,
      publishableKey,
    });
  } catch (err) {
    console.error("Connect route error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
