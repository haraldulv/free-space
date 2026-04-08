import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import Stripe from "stripe";
import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";

const bankSchema = z.object({
  iban: z
    .string()
    .transform((s) => s.replace(/\s+/g, "").toUpperCase())
    .pipe(z.string().regex(/^NO\d{13}$/, "Ugyldig norsk IBAN (forventet NO + 13 siffer)")),
  accountHolderName: z.string().min(2, "Kontoeier må oppgis"),
});

/**
 * POST /api/stripe/account/bank
 *
 * Attaches a Norwegian bank account (IBAN) as the external account for
 * payouts. The IBAN is normalized (whitespace removed, uppercased) before
 * validation and before being sent to Stripe.
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json().catch(() => ({}));
    const parsed = bankSchema.safeParse(body);
    if (!parsed.success) {
      const first = parsed.error.issues[0];
      return NextResponse.json(
        {
          error: first?.message ?? "Ugyldig forespørsel",
          field: first?.path.join("."),
        },
        { status: 400 },
      );
    }

    // Authenticate — Bearer (iOS) or cookies (web)
    let userId: string;
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
    } else {
      const supabase = await createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
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
      return NextResponse.json(
        { error: "Ingen Stripe-konto funnet. Kontakt support." },
        { status: 400 },
      );
    }

    try {
      await stripe.accounts.createExternalAccount(accountId, {
        external_account: {
          object: "bank_account",
          country: "NO",
          currency: "nok",
          account_number: parsed.data.iban,
          account_holder_name: parsed.data.accountHolderName,
          account_holder_type: "individual",
        },
      });
    } catch (err) {
      if (err instanceof Stripe.errors.StripeInvalidRequestError) {
        return NextResponse.json(
          { error: err.message, field: err.param ?? null },
          { status: 400 },
        );
      }
      throw err;
    }

    const account = await stripe.accounts.retrieve(accountId);

    return NextResponse.json({
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
    console.error("Bank account error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
