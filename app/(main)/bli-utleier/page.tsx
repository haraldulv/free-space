"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import ListingFormWizard from "@/components/features/listing-form/ListingFormWizard";
import { createListingAction } from "./actions";

export default function BliUtleierPage() {
  const router = useRouter();
  const [userId, setUserId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(({ data }) => {
      if (!data.user) {
        router.push("/login");
        return;
      }
      setUserId(data.user.id);
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

  return (
    <ListingFormWizard
      userId={userId}
      onSubmit={async (data) => { await createListingAction(data); }}
    />
  );
}
