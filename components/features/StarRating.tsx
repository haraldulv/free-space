"use client";

import { Star } from "lucide-react";

interface StarRatingProps {
  rating: number;
  onRate?: (rating: number) => void;
  size?: "sm" | "md";
}

export default function StarRating({ rating, onRate, size = "md" }: StarRatingProps) {
  const iconSize = size === "sm" ? "h-4 w-4" : "h-5 w-5";

  return (
    <div className="flex items-center gap-0.5">
      {[1, 2, 3, 4, 5].map((star) => (
        <button
          key={star}
          type="button"
          disabled={!onRate}
          onClick={() => onRate?.(star)}
          className={onRate ? "cursor-pointer transition-transform hover:scale-110" : "cursor-default"}
        >
          <Star
            className={`${iconSize} ${
              star <= rating
                ? "fill-amber-400 text-amber-400"
                : "fill-none text-neutral-300"
            }`}
          />
        </button>
      ))}
    </div>
  );
}
