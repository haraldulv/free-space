"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { CreditCard, ArrowRight } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import ListingFormWizard from "@/components/features/listing-form/ListingFormWizard";
import Button from "@/components/ui/Button";
import Container from "@/components/ui/Container";
import { createListingAction } from "./actions";

export default function BliUtleierPage() {
  const router = useRouter();
  const [userId, setUserId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [stripeReady, setStripeReady] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data }) => {
      if (!data.user) {
        router.push("/login");
        return;
      }
      setUserId(data.user.id);

      // Check if host has Stripe Connect set up
      const { data: profile } = await supabase
        .from("profiles")
        .select("stripe_onboarding_complete")
        .eq("id", data.user.id)
        .single();

      setStripeReady(profile?.stripe_onboarding_complete === true);
      setLoading(false);
    });
  }, [router]);

  if (loading || !userId) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <p className="text-sm text-neutral-400">Laster...</p>
      </div>
    );
  }

  if (!stripeReady) {
    return (
      <Container className="py-16">
        <div className="mx-auto max-w-md text-center">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-primary-50">
            <CreditCard className="h-8 w-8 text-primary-600" />
          </div>
          <h1 className="mt-6 text-2xl font-bold text-neutral-900">
            Sett opp utbetalinger
          </h1>
          <p className="mt-3 text-neutral-600">
            Før du kan opprette en annonse, må du koble til Stripe for å motta utbetalinger fra gjester.
          </p>
          <Button
            className="mt-6"
            onClick={() => router.push("/dashboard?tab=settings")}
          >
            Gå til innstillinger
            <ArrowRight className="ml-1.5 h-4 w-4" />
          </Button>
        </div>
      </Container>
    );
  }

  return (
    <ListingFormWizard
      userId={userId}
      onSubmit={async (data) => {
        const result = await createListingAction(data);
        if (result.error) throw new Error(result.error);
      }}
    />
  );
}
