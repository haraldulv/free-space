"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Map, List, Maximize2, Minimize2 } from "lucide-react";
import { Listing, ListingCategory, VehicleType } from "@/types";
import { getUserFavorites } from "@/lib/supabase/favorites";
import SearchResultsList from "./SearchResultsList";
import SearchMap, { type MapBounds } from "./SearchMap";

interface SearchResultsViewProps {
  listings: Listing[];
  query?: string;
  category?: ListingCategory;
  vehicleType?: VehicleType;
  checkIn?: string;
  checkOut?: string;
}

export default function SearchResultsView({
  listings,
}: SearchResultsViewProps) {
  const [hoveredListingId, setHoveredListingId] = useState<string | null>(null);
  const [selectedListingId, setSelectedListingId] = useState<string | null>(
    null,
  );
  const [mobileView, setMobileView] = useState<"list" | "map">("list");
  const [mapFullscreen, setMapFullscreen] = useState(false);
  const [mapBounds, setMapBounds] = useState<MapBounds | null>(null);
  const [favoriteIds, setFavoriteIds] = useState<Set<string>>(new Set());

  useEffect(() => {
    getUserFavorites().then(setFavoriteIds);
  }, []);

  const handleFavoriteToggle = useCallback((listingId: string, favorited: boolean) => {
    setFavoriteIds((prev) => {
      const next = new Set(prev);
      if (favorited) next.add(listingId);
      else next.delete(listingId);
      return next;
    });
  }, []);

  const handleBoundsChange = useCallback((bounds: MapBounds) => {
    setMapBounds(bounds);
  }, []);

  // Filter listings to those visible on the map (with slight padding for edge markers)
  const visibleListings = useMemo(() => {
    if (!mapBounds) return listings;
    const latPad = (mapBounds.north - mapBounds.south) * 0.05;
    const lngPad = (mapBounds.east - mapBounds.west) * 0.05;
    return listings.filter(
      (l) =>
        l.location.lat >= mapBounds.south - latPad &&
        l.location.lat <= mapBounds.north + latPad &&
        l.location.lng >= mapBounds.west - lngPad &&
        l.location.lng <= mapBounds.east + lngPad,
    );
  }, [listings, mapBounds]);

  return (
    <div className="relative overflow-hidden" style={{ height: "calc(100dvh - 64px)" }}>
      {/* List panel */}
      <div
        className={`absolute top-0 left-0 bottom-0 overflow-y-auto scrollbar-hide lg:w-1/2 ${
          mobileView === "map" || mapFullscreen ? "hidden lg:hidden" : "block lg:block right-0 lg:right-auto"
        }`}
      >
        <SearchResultsList
          listings={visibleListings}
          favoriteIds={favoriteIds}
          onFavoriteToggle={handleFavoriteToggle}
          hoveredListingId={hoveredListingId}
          selectedListingId={selectedListingId}
          onHover={setHoveredListingId}
          onSelect={setSelectedListingId}
        />
      </div>

      {/* Map panel — absolutely positioned, adjusts left edge */}
      <div
        className={`absolute top-0 right-0 bottom-0 ${
          mapFullscreen
            ? "left-0"
            : mobileView === "list"
              ? "hidden lg:block lg:left-1/2"
              : "left-0 lg:left-1/2"
        }`}
      >
        <div className="relative h-full w-full">
          <SearchMap
            listings={listings}
            hoveredListingId={hoveredListingId}
            selectedListingId={selectedListingId}
            onHover={setHoveredListingId}
            onSelect={setSelectedListingId}
            onBoundsChange={handleBoundsChange}
          />

          {/* Fullscreen toggle — desktop */}
          <button
            onClick={() => setMapFullscreen(!mapFullscreen)}
            className="absolute top-5 right-5 z-[1000] hidden lg:flex h-9 w-9 items-center justify-center rounded-lg bg-white shadow-md transition-colors hover:bg-neutral-100"
            aria-label={mapFullscreen ? "Lukk fullskjerm" : "Fullskjerm kart"}
          >
            {mapFullscreen ? (
              <Minimize2 className="h-4 w-4 text-neutral-600" />
            ) : (
              <Maximize2 className="h-4 w-4 text-neutral-600" />
            )}
          </button>
        </div>
      </div>

      {/* Mobile toggle */}
      <button
        onClick={() =>
          setMobileView((v) => (v === "list" ? "map" : "list"))
        }
        className="fixed bottom-[calc(1.5rem+env(safe-area-inset-bottom))] left-1/2 z-50 flex -translate-x-1/2 items-center gap-2 rounded-full bg-primary-600 px-6 py-3 text-sm font-medium text-white shadow-lg transition-colors hover:bg-primary-700 lg:hidden"
      >
        {mobileView === "list" ? (
          <>
            <Map className="h-4 w-4" />
            Vis kart
          </>
        ) : (
          <>
            <List className="h-4 w-4" />
            Vis liste
          </>
        )}
      </button>
    </div>
  );
}
