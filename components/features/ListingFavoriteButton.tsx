"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import FavoriteButton from "./FavoriteButton";

export default function ListingFavoriteButton({ listingId }: { listingId: string }) {
  const [isFavorited, setIsFavorited] = useState(false);
  const [loaded, setLoaded] = useState(false);

  useEffect(() => {
    const supabase = createClient();

    async function checkFavorite(userId: string) {
      const { data } = await supabase
        .from("favorites")
        .select("id")
        .eq("user_id", userId)
        .eq("listing_id", listingId)
        .maybeSingle();
      setIsFavorited(!!data);
      setLoaded(true);
    }

    // Check immediately with current session
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user) {
        checkFavorite(session.user.id);
      } else {
        setLoaded(true);
      }
    });

    // Also listen for auth state changes (session may arrive after hydration)
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) {
        checkFavorite(session.user.id);
      }
    });

    return () => subscription.unsubscribe();
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
