import { NextRequest, NextResponse } from "next/server";
import { stripe } from "@/lib/stripe";

/**
 * GET /api/admin/inspect-payouts?account=acct_xxx
 *
 * Read-only debug-endpoint. Returnerer Stripe Connect-konto-status, balance,
 * external accounts (banker), payout schedule, requirements, og siste
 * transfers + payouts. Sikret med CRON_SECRET.
 *
 * Brukes for å feilsøke "verten har ikke fått utbetalt"-saker.
 */
export async function GET(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const accountId = request.nextUrl.searchParams.get("account");
  if (!accountId || !accountId.startsWith("acct_")) {
    return NextResponse.json(
      { error: "Mangler ?account=acct_xxx" },
      { status: 400 },
    );
  }

  try {
    const [account, balance, externals, payouts, transfers] = await Promise.all([
      stripe.accounts.retrieve(accountId),
      stripe.balance.retrieve({ stripeAccount: accountId }),
      stripe.accounts.listExternalAccounts(accountId, { limit: 20 }),
      stripe.payouts.list({ limit: 20 }, { stripeAccount: accountId }),
      stripe.transfers.list({ destination: accountId, limit: 20 }),
    ]);

    const externalSummary = externals.data.map((ext) => {
      if (ext.object === "bank_account") {
        const ba = ext as unknown as {
          id: string;
          last4?: string;
          country?: string;
          currency?: string;
          status?: string;
          default_for_currency?: boolean;
        };
        return {
          type: "bank_account",
          id: ba.id,
          last4: ba.last4,
          country: ba.country,
          currency: ba.currency,
          status: ba.status,
          default_for_currency: ba.default_for_currency,
        };
      }
      const card = ext as unknown as { id: string; brand?: string; last4?: string };
      return {
        type: "card",
        id: card.id,
        brand: card.brand,
        last4: card.last4,
      };
    });

    return NextResponse.json({
      account: {
        id: account.id,
        email: account.email,
        country: account.country,
        default_currency: account.default_currency,
        charges_enabled: account.charges_enabled,
        payouts_enabled: account.payouts_enabled,
        details_submitted: account.details_submitted,
        capabilities: account.capabilities,
        requirements: {
          currently_due: account.requirements?.currently_due ?? [],
          eventually_due: account.requirements?.eventually_due ?? [],
          past_due: account.requirements?.past_due ?? [],
          pending_verification: account.requirements?.pending_verification ?? [],
          disabled_reason: account.requirements?.disabled_reason ?? null,
        },
        future_requirements: {
          currently_due: account.future_requirements?.currently_due ?? [],
          past_due: account.future_requirements?.past_due ?? [],
          disabled_reason: account.future_requirements?.disabled_reason ?? null,
        },
        payout_schedule: account.settings?.payouts?.schedule ?? null,
        debit_negative_balances: account.settings?.payouts?.debit_negative_balances ?? null,
      },
      balance: {
        available: balance.available,
        pending: balance.pending,
        instant_available: (balance as unknown as { instant_available?: unknown }).instant_available ?? null,
        connect_reserved: (balance as unknown as { connect_reserved?: unknown }).connect_reserved ?? null,
      },
      external_accounts: externalSummary,
      recent_payouts: payouts.data.map((p) => ({
        id: p.id,
        amount: p.amount,
        currency: p.currency,
        status: p.status,
        method: p.method,
        type: p.type,
        arrival_date: p.arrival_date,
        created: p.created,
        failure_code: p.failure_code,
        failure_message: p.failure_message,
        statement_descriptor: p.statement_descriptor,
        destination:
          typeof p.destination === "string" ? p.destination : p.destination?.id,
      })),
      recent_transfers: transfers.data.map((t) => ({
        id: t.id,
        amount: t.amount,
        currency: t.currency,
        created: t.created,
        destination:
          typeof t.destination === "string" ? t.destination : t.destination?.id,
        metadata: t.metadata,
      })),
    });
  } catch (err) {
    console.error("Inspect payouts error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Stripe-feil" },
      { status: 500 },
    );
  }
}
