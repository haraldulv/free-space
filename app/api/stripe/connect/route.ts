import { NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import { createConnectAccount, stripe } from "@/lib/stripe";

/**
 * POST /api/stripe/connect
 *
 * Creates a Custom Stripe Connect account if one doesn't exist, then returns
 * the current onboarding state (requirements + capabilities). The iOS app
 * (and eventually web) uses this as the entry point to the native onboarding
 * flow and for status polling.
 */
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
        process.env.SUPABASE_SERVICE_ROLE_KEY!,
      );
      const {
        data: { user },
        error,
      } = await supabase.auth.getUser(authHeader.slice(7));
      if (error || !user) {
        return NextResponse.json({ error: "Ugyldig token" }, { status: 401 });
      }
      userId = user.id;
      userEmail = user.email || "";
    } else {
      const supabase = await createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        return NextResponse.json({ error: "Ikke innlogget" }, { status: 401 });
      }
      userId = user.id;
      userEmail = user.email || "";
    }

    const db = createServiceClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
    );

    const { data: profile } = await db
      .from("profiles")
      .select("stripe_account_id, full_name, stripe_onboarding_complete")
      .eq("id", userId)
      .single();

    let accountId = profile?.stripe_account_id as string | null | undefined;

    if (!accountId) {
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

    // Pull the current account state from Stripe. The native client uses
    // `requirements.currently_due` to know which steps the user still needs
    // to complete, and `charges_enabled`/`payouts_enabled` to show the final
    // "ready" status.
    const account = await stripe.accounts.retrieve(accountId);

    // Synk fullført-flagget også fra POLLING, ikke bare webhooken.
    // Uten dette var appen prisgitt account.updated-webhooken (som kan
    // være treg/feilkonfigurert per miljø) før annonsene ble synlige —
    // «Stripe-verifisering tar lang tid»-funnet fra Kims test 2026-10-11.
    const isComplete =
      (account.charges_enabled ?? false) &&
      (account.requirements?.currently_due ?? []).length === 0;
    if (isComplete && profile?.stripe_onboarding_complete !== true) {
      await db
        .from("profiles")
        .update({ stripe_onboarding_complete: true })
        .eq("id", userId);
    }

    return NextResponse.json({
      accountId,
      requirements: {
        currently_due: account.requirements?.currently_due ?? [],
        eventually_due: account.requirements?.eventually_due ?? [],
        past_due: account.requirements?.past_due ?? [],
        disabled_reason: account.requirements?.disabled_reason ?? null,
      },
      charges_enabled: account.charges_enabled ?? false,
      payouts_enabled: account.payouts_enabled ?? false,
    });
  } catch (err) {
    console.error("Connect route error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
