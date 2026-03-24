"use client";

import { useEffect, useRef } from "react";
import Link from "next/link";
import { Star } from "lucide-react";
import { Listing } from "@/types";
import ImageCarousel from "@/components/features/ImageCarousel";

interface SearchListingCardProps {
  listing: Listing;
  isHovered: boolean;
  isSelected: boolean;
  onMouseEnter: () => void;
  onMouseLeave: () => void;
  onClick: () => void;
}

export default function SearchListingCard({
  listing,
  isHovered,
  isSelected,
  onMouseEnter,
  onMouseLeave,
  onClick,
}: SearchListingCardProps) {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (isSelected && ref.current) {
      ref.current.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }
  }, [isSelected]);

  return (
    <div
      ref={ref}
      onMouseEnter={onMouseEnter}
      onMouseLeave={onMouseLeave}
      onClick={onClick}
      className={`group cursor-pointer rounded-lg border transition-all duration-200 bg-white ${
        isSelected
          ? "border-primary-600 shadow-md ring-1 ring-primary-600"
          : isHovered
            ? "border-primary-400 shadow-md"
            : "border-neutral-200 hover:border-neutral-300 hover:shadow-sm"
      }`}
    >
      <div className="overflow-hidden rounded-t-lg">
        <ImageCarousel
          images={listing.images}
          alt={listing.title}
        />
      </div>
      <Link href={`/listings/${listing.id}`} className="block">
        <div className="px-2.5 py-2">
          <div className="flex items-start justify-between gap-1">
            <h3 className="text-sm font-medium text-neutral-900 line-clamp-1">
              {listing.title}
            </h3>
            <div className="flex shrink-0 items-center gap-0.5">
              <Star className="h-3 w-3 fill-neutral-900 text-neutral-900" />
              <span className="text-xs text-neutral-900">
                {listing.rating}
              </span>
            </div>
          </div>
          <p className="text-xs text-neutral-500 line-clamp-1">
            {listing.location.city}, {listing.location.region}
          </p>
          <p className="mt-0.5 text-sm text-neutral-900">
            <span className="font-semibold">{listing.price} kr</span>
            <span className="font-normal text-neutral-500">
              {" "}/ {listing.priceUnit === "time" ? "dag" : "natt"}
            </span>
          </p>
        </div>
      </Link>
    </div>
  );
}
