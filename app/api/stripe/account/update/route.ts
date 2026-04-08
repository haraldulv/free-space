import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import Stripe from "stripe";
import { createClient } from "@/lib/supabase/server";
import { createClient as createServiceClient } from "@supabase/supabase-js";
import { stripe } from "@/lib/stripe";

const updateSchema = z.object({
  individual: z
    .object({
      first_name: z.string().min(1).optional(),
      last_name: z.string().min(1).optional(),
      dob: z
        .object({
          day: z.number().int().min(1).max(31),
          month: z.number().int().min(1).max(12),
          year: z.number().int().min(1900).max(new Date().getFullYear()),
        })
        .optional(),
      id_number: z
        .string()
        .regex(/^\d{11}$/, "Personnummer må være 11 siffer")
        .optional(),
      phone: z.string().min(8).optional(),
      email: z.string().email().optional(),
      address: z
        .object({
          line1: z.string().min(1),
          postal_code: z.string().min(4),
          city: z.string().min(1),
          country: z.literal("NO").default("NO"),
        })
        .optional(),
    })
    .optional(),
  tos_acceptance: z
    .object({
      accepted: z.literal(true),
    })
    .optional(),
});

/**
 * POST /api/stripe/account/update
 *
 * Proxies a structured payload from the native onboarding flow to
 * `stripe.accounts.update()`. Each step in the app submits only the fields
 * relevant to that step, and we merge them into the Stripe account. TOS
 * acceptance is stamped server-side with date/ip/user_agent.
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json().catch(() => ({}));
    const parsed = updateSchema.safeParse(body);
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

    const updateParams: Stripe.AccountUpdateParams = {};

    if (parsed.data.individual) {
      const src = parsed.data.individual;
      const individual: Stripe.AccountUpdateParams.Individual = {};
      if (src.first_name) individual.first_name = src.first_name;
      if (src.last_name) individual.last_name = src.last_name;
      if (src.dob) individual.dob = src.dob;
      if (src.id_number) individual.id_number = src.id_number;
      if (src.phone) individual.phone = src.phone;
      if (src.email) individual.email = src.email;
      if (src.address) {
        individual.address = {
          line1: src.address.line1,
          postal_code: src.address.postal_code,
          city: src.address.city,
          country: "NO",
        };
      }
      updateParams.individual = individual;
    }

    if (parsed.data.tos_acceptance?.accepted) {
      const forwardedFor = request.headers.get("x-forwarded-for") ?? "";
      const ip = forwardedFor.split(",")[0]?.trim() || "0.0.0.0";
      updateParams.tos_acceptance = {
        date: Math.floor(Date.now() / 1000),
        ip,
        user_agent: request.headers.get("user-agent") ?? undefined,
      };
    }

    let account: Stripe.Account;
    try {
      account = await stripe.accounts.update(accountId, updateParams);
    } catch (err) {
      if (err instanceof Stripe.errors.StripeInvalidRequestError) {
        return NextResponse.json(
          { error: err.message, field: err.param ?? null },
          { status: 400 },
        );
      }
      throw err;
    }

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
    console.error("Account update error:", err);
    return NextResponse.json(
      { error: err instanceof Error ? err.message : "Noe gikk galt" },
      { status: 500 },
    );
  }
}
