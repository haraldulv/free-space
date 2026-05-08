"use client";

import { useEffect, useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { useRouter } from "@/i18n/navigation";
import { loadStripe } from "@stripe/stripe-js";
import { Elements, PaymentElement, useStripe, useElements } from "@stripe/react-stripe-js";
import { Loader2, ShieldCheck } from "lucide-react";
import Button from "@/components/ui/Button";
import Container from "@/components/ui/Container";
import { useLocale } from "next-intl";
import { stripeLocale } from "@/lib/i18n-helpers";

function PaymentInner({ clientSecret, bookingId }: { clientSecret: string; bookingId: string }) {
  const router = useRouter();
  const stripe = useStripe();
  const elements = useElements();
  const [processing, setProcessing] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!stripe || !elements) return;

    setProcessing(true);
    setError("");

    const { error: submitError, paymentIntent } = await stripe.confirmPayment({
      elements,
      redirect: "if_required",
      confirmParams: {
        return_url: `${window.location.origin}/book/confirmation?bookingId=${bookingId}`,
      },
    });

    if (submitError) {
      setError(submitError.message || "Betaling feilet");
      setProcessing(false);
      return;
    }

    if (paymentIntent?.status === "succeeded") {
      // Server idempotent confirm + redirect til bekreftelse.
      try {
        const { createClient } = await import("@/lib/supabase/client");
        const supabase = createClient();
        const { data: { session } } = await supabase.auth.getSession();
        if (session) {
          await fetch("/api/bookings/payment-confirmed", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${session.access_token}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ bookingId }),
          });
        }
      } catch (err) {
        console.warn("payment-confirmed call failed (non-fatal):", err);
      }
      router.push(`/book/confirmation?bookingId=${bookingId}`);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <PaymentElement />
      {error && <p className="text-sm text-red-600">{error}</p>}
      <div className="flex items-center gap-2 rounded-lg bg-primary-50 p-3 text-sm text-primary-700">
        <ShieldCheck className="h-5 w-5 shrink-0" />
        Betalingen behandles av Stripe. Tuno mottar aldri kortinformasjonen din.
      </div>
      <Button type="submit" size="lg" className="w-full" disabled={!stripe || processing}>
        {processing ? (
          <span className="inline-flex items-center gap-2">
            <Loader2 className="h-4 w-4 animate-spin" />
            Behandler...
          </span>
        ) : (
          "Fullfør betaling"
        )}
      </Button>
    </form>
  );
}

function PaymentPageContent() {
  const searchParams = useSearchParams();
  const locale = useLocale();
  const [stripePromise, setStripePromise] = useState<ReturnType<typeof loadStripe> | null>(null);

  const clientSecret = searchParams.get("clientSecret") || "";
  const bookingId = searchParams.get("bookingId") || "";
  const publishableKey = searchParams.get("publishableKey") || process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY || "";

  useEffect(() => {
    if (publishableKey) {
      setStripePromise(loadStripe(publishableKey));
    }
  }, [publishableKey]);

  if (!clientSecret || !bookingId) {
    return (
      <Container className="py-10">
        <h1 className="text-2xl font-bold text-neutral-900">Mangler betalingsinformasjon</h1>
        <p className="mt-4 text-neutral-500">
          Lenken er ufullstendig. Gå til meldinger-fanen og åpne samtalen for å fullføre betalingen.
        </p>
      </Container>
    );
  }

  if (!stripePromise) {
    return (
      <Container className="py-10">
        <p className="text-neutral-500">Laster...</p>
      </Container>
    );
  }

  return (
    <Container className="max-w-xl py-10">
      <h1 className="text-2xl font-bold text-neutral-900">Fullfør betaling</h1>
      <p className="mt-1 text-sm text-neutral-500">
        Tilbudet er godtatt. Fullfør innen 24 timer for å bekrefte bestillingen.
      </p>
      <div className="mt-6 rounded-2xl border border-neutral-200 bg-white p-6">
        <Elements
          stripe={stripePromise}
          options={{
            clientSecret,
            locale: stripeLocale(locale),
            appearance: { theme: "stripe" },
          }}
        >
          <PaymentInner clientSecret={clientSecret} bookingId={bookingId} />
        </Elements>
      </div>
    </Container>
  );
}

export default function PaymentPage() {
  return (
    <Suspense fallback={<Container className="py-10"><p className="text-neutral-500">Laster...</p></Container>}>
      <PaymentPageContent />
    </Suspense>
  );
}
