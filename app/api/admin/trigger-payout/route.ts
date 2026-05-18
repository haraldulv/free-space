import { NextRequest, NextResponse } from "next/server";
import Stripe from "stripe";
import { stripe } from "@/lib/stripe";

/**
 * POST /api/admin/trigger-payout
 * Body: { account: "acct_xxx", amount?: number (i øre, default = all available NOK) }
 *
 * Sikret med CRON_SECRET. Trigger en manuell Stripe-payout fra en Connect-konto
 * til kontoens default external_account. Brukes for å diagnostisere hvorfor
 * automatisk daily-schedule ikke har trigget — feilkoden Stripe returnerer
 * forteller oss om problemet er bank-verifikasjon, minimum-threshold, reserve,
 * eller annet.
 */
export async function POST(request: NextRequest) {
  const authHeader = request.headers.get("authorization");
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json().catch(() => ({}));
  const account = body.account as string | undefined;
  const requestedAmount = body.amount as number | undefined;

  if (!account || !account.startsWith("acct_")) {
    return NextResponse.json(
      { error: "Mangler body.account=acct_xxx" },
      { status: 400 },
    );
  }

  try {
    const balance = await stripe.balance.retrieve({ stripeAccount: account });
    const availableNok = balance.available.find((b) => b.currency === "nok");
    const availableAmount = availableNok?.amount ?? 0;

    const amount = requestedAmount ?? availableAmount;
    if (amount <= 0) {
      return NextResponse.json(
        {
          error: "Ingen tilgjengelig balanse",
          available: balance.available,
          pending: balance.pending,
        },
        { status: 400 },
      );
    }

    const payout = await stripe.payouts.create(
      { amount, currency: "nok" },
      { stripeAccount: account },
    );

    return NextResponse.json({
      success: true,
      payout: {
        id: payout.id,
        amount: payout.amount,
        currency: payout.currency,
        status: payout.status,
        method: payout.method,
        arrival_date: payout.arrival_date,
        failure_code: payout.failure_code,
        failure_message: payout.failure_message,
      },
      balance_before: {
        available: balance.available,
        pending: balance.pending,
      },
    });
  } catch (err) {
    if (err instanceof Stripe.errors.StripeError) {
      return NextResponse.json(
        {
          success: false,
          error: {
            type: err.type,
            code: err.code,
            decline_code: (err as { decline_code?: string }).decline_code,
            param: err.param,
            message: err.message,
            statusCode: err.statusCode,
            requestId: err.requestId,
          },
        },
        { status: 200 },
      );
    }
    console.error("Trigger payout error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Ukjent feil" },
      { status: 500 },
    );
  }
}
