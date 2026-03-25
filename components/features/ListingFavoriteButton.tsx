"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import FavoriteButton from "./FavoriteButton";

export default function ListingFavoriteButton({ listingId }: { listingId: string }) {
  const [isFavorited, setIsFavorited] = useState(false);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async ({ data: { user } }) => {
      if (!user) { setLoaded(true); return; }
      const { data } = await supabase
        .from("favorites")
        .select("id")
        .eq("user_id", user.id)
        .eq("listing_id", listingId)
        .maybeSingle();
      setIsFavorited(!!data);
      setLoaded(true);
    });
  }, [listingId]);

  if (!loaded) return null;

  return (
    <FavoriteButton
      listingId={listingId}
      isFavorited={isFavorited}
      size="md"
    />
  );
}
