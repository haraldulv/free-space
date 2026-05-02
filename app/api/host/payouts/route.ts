import { NextRequest, NextResponse } from "next/server";
import { stripe } from "@/lib/stripe";
import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";

/**
 * GET /api/host/payouts
 *
 * Henter hostens utbetalingsstatus direkte fra Stripe Connect-kontoen.
 * Returnerer:
 *  - balance: tilgjengelig + pending balance
 *  - account_status: payouts_enabled + currently_due
 *  - payouts: liste over siste utbetalinger med status
 *  - external_accounts: hvilken bank-konto pengene går til
 *
 * Brukes av iOS-Inntekter-fanen for å vise hosten en transparent
 * oversikt over hva de har fått, hva som er på vei, og hva som er
 * blokkert.
 */
export async function GET(request: NextRequest) {
  try {
    // Auth — Bearer (iOS) eller cookies (web)
    let userId: string;
    const authHeader = request.headers.get("authorization");
    if (authHeader?.startsWith("Bearer ")) {
      const sb = createServiceClient(
        process.env.NEXT_PUBLIC_SUPABASE_URL!,
        process.env.SUPABASE_SERVICE_ROLE_KEY!,
      );
      const { data: { user }, error } = await sb.auth.getUser(authHeader.slice(7));
      if (error || !user) {
        return NextResponse.json({ error: "Ugyldig token" }, { status: 401 });
      }
      userId = user.id;
    } else {
      const sb = await createClient();
      const { data: { user } } = await sb.auth.getUser();
      if (!user) {
        return NextResponse.json({ error: "Ikke innlogget" }, { status: 401 });
      }
      userId = user.id;
    }

    const db = createServiceClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!,
    );

    const { data: profile } = await db
      .from("profiles")
      .select("stripe_account_id")
      .eq("id", userId)
      .single();

    const accountId = profile?.stripe_account_id as string | null | undefined;
    if (!accountId) {
      return NextResponse.json({
        has_stripe_account: false,
        balance: null,
        account_status: null,
        payouts: [],
        external_accounts: [],
      });
    }

    const [account, balance, externalAccounts, payouts] = await Promise.all([
      stripe.accounts.retrieve(accountId),
      stripe.balance.retrieve({ stripeAccount: accountId }),
      stripe.accounts.listExternalAccounts(accountId, { limit: 5 }),
      stripe.payouts.list({ limit: 20 }, { stripeAccount: accountId }),
    ]);

    const availableNok =
      balance.available
        .filter((b) => b.currency === "nok")
        .reduce((sum, b) => sum + b.amount, 0) / 100;
    const pendingNok =
      balance.pending
        .filter((b) => b.currency === "nok")
        .reduce((sum, b) => sum + b.amount, 0) / 100;

    const externalSummary = externalAccounts.data.map((ext) => {
      if (ext.object === "bank_account") {
        const ba = ext as unknown as {
          last4?: string;
          country?: string;
          currency?: string;
          status?: string;
          default_for_currency?: boolean;
        };
        return {
          type: "bank_account" as const,
          last4: ba.last4 ?? null,
          country: ba.country ?? null,
          currency: ba.currency ?? null,
          status: ba.status ?? null,
          default_for_currency: ba.default_for_currency ?? false,
        };
      }
      return null;
    }).filter((x): x is NonNullable<typeof x> => x !== null);

    return NextResponse.json({
      has_stripe_account: true,
      balance: {
        available_nok: availableNok,
        pending_nok: pendingNok,
      },
      account_status: {
        payouts_enabled: account.payouts_enabled,
        charges_enabled: account.charges_enabled,
        currently_due: account.requirements?.currently_due ?? [],
        past_due: account.requirements?.past_due ?? [],
        disabled_reason: account.requirements?.disabled_reason ?? null,
        payout_schedule: account.settings?.payouts?.schedule?.interval ?? null,
      },
      external_accounts: externalSummary,
      payouts: payouts.data.map((p) => ({
        id: p.id,
        amount_nok: p.amount / 100,
        currency: p.currency,
        status: p.status, // 'paid' | 'pending' | 'in_transit' | 'canceled' | 'failed'
        method: p.method,
        arrival_date: p.arrival_date, // unix seconds
        created: p.created,
        failure_message: p.failure_message,
        bank_last4:
          typeof p.destination === "string"
            ? null
            : (p.destination as unknown as { last4?: string })?.last4 ?? null,
      })),
    });
  } catch (err) {
    console.error("Host payouts error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Stripe-feil" },
      { status: 500 },
    );
  }
}
