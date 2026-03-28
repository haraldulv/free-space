import Stripe from "stripe";

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  typescript: true,
});

/** Create a Stripe Connect Express account for a host */
export async function createConnectAccount(email: string): Promise<Stripe.Account> {
  return stripe.accounts.create({
    type: "express",
    country: "NO",
    email,
    capabilities: {
      transfers: { requested: true },
    },
    settings: {
      payouts: {
        schedule: { interval: "manual" },
      },
    },
  });
}

/** Create an account onboarding link */
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
