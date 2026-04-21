"use client";

import { useEffect, useRef } from "react";
import { Star, Zap } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import { Listing, getDisplayPriceText } from "@/types";
import { haversineKm, formatDistance } from "@/lib/geo";
import type { UserLocation } from "@/lib/hooks/useUserLocation";
import ImageCarousel from "@/components/features/ImageCarousel";
import FavoriteButton from "@/components/features/FavoriteButton";

interface SearchListingCardProps {
  listing: Listing;
  isFavorited?: boolean;
  onFavoriteToggle?: (listingId: string, favorited: boolean) => void;
  isHovered: boolean;
  isSelected: boolean;
  onMouseEnter: () => void;
  onMouseLeave: () => void;
  onClick: () => void;
  userLocation?: UserLocation | null;
}

export default function SearchListingCard({
  listing,
  isFavorited = false,
  onFavoriteToggle,
  isHovered,
  isSelected,
  onMouseEnter,
  onMouseLeave,
  onClick,
  userLocation,
}: SearchListingCardProps) {
  const t = useTranslations("listing");
  const locale = useLocale();
  const ref = useRef<HTMLDivElement>(null);

  const distanceKm = userLocation
    ? haversineKm(userLocation.lat, userLocation.lng, listing.location.lat, listing.location.lng)
    : null;

  useEffect(() => {
    if (isSelected && ref.current) {
      ref.current.scrollIntoView({ behavior: "smooth", block: "nearest" });
    }
  }, [isSelected]);

  const priceUnitLabel = listing.priceUnit === "time" ? t("hour") : t("night");

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
      <div className="relative overflow-hidden rounded-t-lg">
        <ImageCarousel
          images={listing.images}
          alt={listing.title}
        />
        <div className="absolute top-2 right-2 z-10">
          <FavoriteButton
            listingId={listing.id}
            isFavorited={isFavorited}
            onToggle={(fav) => onFavoriteToggle?.(listing.id, fav)}
          />
        </div>
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
            {distanceKm !== null && (
              <span className="ml-1 text-neutral-400">· {formatDistance(distanceKm, locale)}</span>
            )}
          </p>
          <div className="mt-1 flex items-center justify-between">
            <p className="text-sm text-neutral-900">
              <span className="font-semibold">{getDisplayPriceText(listing)} kr</span>
              <span className="font-normal text-neutral-500">
                {" "}/ {priceUnitLabel}
              </span>
            </p>
            <div className="flex items-center gap-1.5">
              {listing.instantBooking && (
                <span className="flex items-center text-[10px] font-semibold text-green-600" title={t("instantBook")}>
                  <Zap className="h-3 w-3 fill-green-600" />
                </span>
              )}
              {listing.spots > 1 && (
                <span
                  className="flex items-center gap-0.5 text-[10px] text-neutral-400"
                  title={
                    listing.availableSpots !== undefined
                      ? t("spotsOfTotalAvailable", { available: listing.availableSpots, total: listing.spots })
                      : t("spotsAvailable", { count: listing.spots })
                  }
                >
                  <svg className="h-3 w-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2" />
                    <circle cx="7" cy="17" r="2" /><path d="M9 17h6" /><circle cx="17" cy="17" r="2" />
                  </svg>
                  {listing.availableSpots !== undefined ? `${listing.availableSpots}/${listing.spots}` : listing.spots}
                </span>
              )}
            </div>
          </div>
        </div>
      </Link>
    </div>
  );
}
