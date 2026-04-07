"use client";

import { useEffect, useMemo, useState } from "react";
import {
  loadConnectAndInitialize,
  type StripeConnectInstance,
} from "@stripe/connect-js";
import {
  ConnectAccountOnboarding,
  ConnectComponentsProvider,
} from "@stripe/react-connect-js";
import { Loader2 } from "lucide-react";

interface Props {
  /** Called after the user finishes (or dismisses) the onboarding flow. */
  onExit: () => void;
}

/**
 * Inline embedded Stripe Connect onboarding for hosts.
 *
 * Wraps `ConnectAccountOnboarding` from `@stripe/react-connect-js`. Fetches a
 * fresh AccountSession `client_secret` from `/api/stripe/connect` whenever
 * Stripe asks for one (the secret expires after ~30 minutes).
 */
export default function StripeConnectOnboarding({ onExit }: Props) {
  const [stripeConnectInstance, setInstance] =
    useState<StripeConnectInstance | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Stable closure that always re-POSTs to get a fresh client secret.
  const fetchClientSecret = useMemo(
    () => async () => {
      const res = await fetch("/api/stripe/connect", { method: "POST" });
      const data = await res.json();
      if (data.error || !data.clientSecret) {
        throw new Error(data.error || "Kunne ikke hente Stripe-sesjon");
      }
      // Side-effect: pick up the publishable key on the first call.
      if (!stripeConnectInstance && data.publishableKey) {
        const instance = loadConnectAndInitialize({
          publishableKey: data.publishableKey,
          fetchClientSecret: async () => {
            const r = await fetch("/api/stripe/connect", { method: "POST" });
            const d = await r.json();
            return d.clientSecret as string;
          },
        });
        setInstance(instance);
      }
      return data.clientSecret as string;
    },
    [stripeConnectInstance],
  );

  // Bootstrap on first mount.
  useEffect(() => {
    let cancelled = false;
    fetchClientSecret().catch((err) => {
      if (!cancelled) {
        setError(err instanceof Error ? err.message : "Noe gikk galt");
      }
    });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (error) {
    return <p className="text-sm text-red-600">{error}</p>;
  }

  if (!stripeConnectInstance) {
    return (
      <div className="flex items-center gap-2 text-sm text-neutral-500">
        <Loader2 className="h-4 w-4 animate-spin" />
        Laster Stripe-onboarding...
      </div>
    );
  }

  return (
    <ConnectComponentsProvider connectInstance={stripeConnectInstance}>
      <ConnectAccountOnboarding onExit={onExit} />
    </ConnectComponentsProvider>
  );
}
