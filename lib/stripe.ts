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
 * the host can correct it inside the onboarding form.
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

/** Create a Stripe Connect Express account for a host */
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
    type: "express",
    country: "NO",
    default_currency: "nok",
    email,
    business_type: "individual",
    business_profile: {
      url: "https://www.tuno.no",
      mcc: "7523",
      product_description:
        "Utleier av parkerings- og bobilplasser via Tuno-plattformen",
    },
    capabilities: {
      transfers: { requested: true },
    },
    settings: {
      payouts: {
        schedule: { interval: "manual" },
      },
    },
    individual,
    metadata: { platform: "tuno" },
  });
}

/** Create an account onboarding link (hosted onboarding — used by web fallback) */
export async function createAccountLink(
  accountId: string,
  returnUrl: string,
  refreshUrl: string,
): Promise<string> {
  const link = await stripe.accountLinks.create({
    account: accountId,
    return_url: returnUrl,
    refresh_url: refreshUrl,
    type: "account_onboarding",
  });
  return link.url;
}

/**
 * Create an Account Session for embedded onboarding components.
 * Used by both iOS (StripeConnect SDK) and web (@stripe/react-connect-js).
 * Client secrets expire ~30 minutes — the embedded component refetches as needed.
 */
export async function createAccountSession(
  accountId: string,
): Promise<Stripe.AccountSession> {
  return stripe.accountSessions.create({
    account: accountId,
    components: {
      account_onboarding: {
        enabled: true,
        features: {
          external_account_collection: true,
        },
      },
    },
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
