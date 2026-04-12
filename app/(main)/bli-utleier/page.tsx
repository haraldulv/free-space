"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import ListingFormWizard from "@/components/features/listing-form/ListingFormWizard";
import HostOnboardingWizard from "@/components/features/HostOnboardingWizard";
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
      <HostOnboardingWizard
        onComplete={() => {
          setStripeReady(true);
        }}
      />
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
