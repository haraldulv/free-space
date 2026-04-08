import Stripe from "stripe";

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  typescript: true,
});

export type ConnectAccountPrefill = {
  email: string;
  fullName?: string | null;
};

/**
 * Split a full name into first/last for Stripe `individual` prefill.
 * Lossy for compound last names ("van der Berg", "Bakke-Hansen Jensen") —
 * the host can correct it inside the native onboarding flow.
 */
function splitName(full?: string | null): {
  first_name?: string;
  last_name?: string;
} {
  const t = (full ?? "").trim().replace(/\s+/g, " ");
  if (!t) return {};
  const parts = t.split(" ");
  if (parts.length === 1) return { first_name: parts[0] };
  return { first_name: parts[0], last_name: parts.slice(1).join(" ") };
}

/**
 * Create a Stripe Connect account with full platform UI ownership.
 *
 * Uses the modern `controller` API (the legacy `type: "custom"` shortcut is
 * deprecated). With `stripe_dashboard.type: "none"` and
 * `requirement_collection: "application"`, Tuno owns 100% of the onboarding
 * UI — no Stripe-hosted pages, no sign-in gate, no embedded components that
 * pop out to connect.stripe.com.
 */
export async function createConnectAccount(
  prefill: ConnectAccountPrefill,
): Promise<Stripe.Account> {
  const { email, fullName } = prefill;
  const name = splitName(fullName);

  const individual: Stripe.AccountCreateParams.Individual = {
    email,
    address: { country: "NO" },
  };
  if (name.first_name) individual.first_name = name.first_name;
  if (name.last_name) individual.last_name = name.last_name;

  return stripe.accounts.create({
    country: "NO",
    email,
    controller: {
      fees: { payer: "application" },
      losses: { payments: "application" },
      requirement_collection: "application",
      stripe_dashboard: { type: "none" },
    },
    capabilities: {
      transfers: { requested: true },
    },
    business_type: "individual",
    business_profile: {
      url: "https://www.tuno.no",
      mcc: "7523",
      product_description:
        "Utleier av parkerings- og bobilplasser via Tuno-plattformen",
    },
    individual,
    settings: {
      payouts: {
        schedule: { interval: "manual" },
      },
    },
    metadata: { platform: "tuno" },
  });
}

/** Create a transfer to a connected account */
export async function createTransfer(
  amount: number,
  destinationAccountId: string,
  metadata: Record<string, string>,
): Promise<Stripe.Transfer> {
  return stripe.transfers.create({
    amount,
    currency: "nok",
    destination: destinationAccountId,
    metadata,
  });
}
