"use client";

import { useTranslations } from "next-intl";
import { Listing } from "@/types";
import SearchListingCard from "./SearchListingCard";

interface SearchResultsListProps {
  listings: Listing[];
  favoriteIds: Set<string>;
  onFavoriteToggle: (listingId: string, favorited: boolean) => void;
  hoveredListingId: string | null;
  selectedListingId: string | null;
  onHover: (id: string | null) => void;
  onSelect: (id: string | null) => void;
}

export default function SearchResultsList({
  listings,
  favoriteIds,
  onFavoriteToggle,
  hoveredListingId,
  selectedListingId,
  onHover,
  onSelect,
}: SearchResultsListProps) {
  const t = useTranslations("search");
  return (
    <div className="px-5 py-3 sm:px-6 lg:px-6">
      <div className="mb-3">
        <h1 className="text-sm font-semibold text-neutral-900">
          {listings.length > 0
            ? t("spotsInArea", { count: listings.length })
            : t("noResults")}
        </h1>
      </div>

      {listings.length === 0 ? (
        <div className="py-16 text-center">
          <p className="text-neutral-500">
            {t("noResultsInArea")}
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-x-4 gap-y-5 sm:grid-cols-2 lg:grid-cols-3">
          {listings.map((listing) => (
            <SearchListingCard
              key={listing.id}
              listing={listing}
              isFavorited={favoriteIds.has(listing.id)}
              onFavoriteToggle={onFavoriteToggle}
              isHovered={hoveredListingId === listing.id}
              isSelected={selectedListingId === listing.id}
              onMouseEnter={() => onHover(listing.id)}
              onMouseLeave={() => onHover(null)}
              onClick={() =>
                onSelect(
                  selectedListingId === listing.id ? null : listing.id,
                )
              }
            />
          ))}
        </div>
      )}
    </div>
  );
}
