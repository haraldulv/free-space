"use client";

import { useState } from "react";
import { Heart } from "lucide-react";
import { toggleFavorite } from "@/lib/supabase/favorites";
import { hapticLight } from "@/lib/haptics";

interface FavoriteButtonProps {
  listingId: string;
  isFavorited: boolean;
  onToggle?: (favorited: boolean) => void;
  size?: "sm" | "md";
}

export default function FavoriteButton({
  listingId,
  isFavorited,
  onToggle,
  size = "sm",
}: FavoriteButtonProps) {
  const [favorited, setFavorited] = useState(isFavorited);
  const [loading, setLoading] = useState(false);

  const handleClick = async (e: React.MouseEvent) => {
    e.preventDefault();
    e.stopPropagation();
    if (loading) return;
    setLoading(true);
    hapticLight();
    try {
      const result = await toggleFavorite(listingId);
      setFavorited(result);
      onToggle?.(result);
    } catch {
      // Not logged in — could redirect to login
    } finally {
      setLoading(false);
    }
  };

  const iconSize = size === "md" ? "h-5 w-5" : "h-4 w-4";
  const padding = size === "md" ? "p-2" : "p-1.5";

  return (
    <button
      onClick={handleClick}
      disabled={loading}
      className={`${padding} rounded-full bg-white/80 backdrop-blur-sm transition-all hover:bg-white hover:scale-110 active:scale-95 disabled:opacity-50`}
      aria-label={favorited ? "Fjern fra favoritter" : "Legg til i favoritter"}
    >
      <Heart
        className={`${iconSize} transition-colors ${
          favorited
            ? "fill-red-500 text-red-500"
            : "fill-transparent text-neutral-600 hover:text-neutral-800"
        }`}
      />
    </button>
  );
}
