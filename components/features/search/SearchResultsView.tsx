"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { Map, List, Maximize2, Minimize2, Calendar } from "lucide-react";
import { useRouter, useSearchParams, usePathname } from "next/navigation";
import { useTranslations } from "next-intl";
import { Listing, ListingCategory, VehicleType, PricePackagePeriodType, PRICE_PACKAGE_PERIOD_LABELS } from "@/types";
import { getUserFavorites } from "@/lib/supabase/favorites";
import { useUserLocation } from "@/lib/hooks/useUserLocation";
import { haversineKm } from "@/lib/geo";
import SearchResultsList from "./SearchResultsList";
import SearchMap, { type MapBounds } from "./SearchMap";

interface SearchResultsViewProps {
  listings: Listing[];
  query?: string;
  category?: ListingCategory;
  vehicleType?: VehicleType;
  checkIn?: string;
  checkOut?: string;
  openingHours?: "any" | "always" | "limited";
  rentalPeriodTypes?: PricePackagePeriodType[];
}

const PERIOD_TYPE_OPTIONS: ReadonlyArray<PricePackagePeriodType> = ["DAY", "WEEK", "MONTH", "YEAR"];

export default function SearchResultsView({
  listings,
  rentalPeriodTypes,
}: SearchResultsViewProps) {
  const t = useTranslations("search");
  // ÅPNINGSTIDER PAUSET pre-launch — re-aktiver tFilter + setOpeningHoursFilter
  // const tFilter = useTranslations("searchFilter.openingHours");
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  // const setOpeningHoursFilter = (value: "any" | "always" | "limited") => {
  //   const params = new URLSearchParams(searchParams?.toString() ?? "");
  //   if (value === "any") params.delete("openingHours");
  //   else params.set("openingHours", value);
  //   const qs = params.toString();
  //   router.push(qs ? `${pathname}?${qs}` : pathname);
  // };

  const togglePeriodType = (value: PricePackagePeriodType) => {
    const params = new URLSearchParams(searchParams?.toString() ?? "");
    const current = new Set(rentalPeriodTypes ?? []);
    if (current.has(value)) current.delete(value);
    else current.add(value);
    if (current.size === 0) params.delete("period");
    else params.set("period", Array.from(current).join(","));
    const qs = params.toString();
    router.push(qs ? `${pathname}?${qs}` : pathname);
  };
  const activePeriodTypes = useMemo(() => new Set(rentalPeriodTypes ?? []), [rentalPeriodTypes]);
  const [hoveredListingId, setHoveredListingId] = useState<string | null>(null);
  const [selectedListingId, setSelectedListingId] = useState<string | null>(
    null,
  );
  const [mobileView, setMobileView] = useState<"list" | "map">("list");
  const [mapFullscreen, setMapFullscreen] = useState(false);
  const [mapBounds, setMapBounds] = useState<MapBounds | null>(null);
  const [favoriteIds, setFavoriteIds] = useState<Set<string>>(new Set());
  const [sortByDistance, setSortByDistance] = useState(false);
  const { location: userLocation, status: geoStatus, request: requestLocation } = useUserLocation();

  // Skru automatisk på distance-sort så snart posisjon er delt
  useEffect(() => {
    if (userLocation && !sortByDistance) {
      setSortByDistance(true);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userLocation]);

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
    const filtered = !mapBounds
      ? listings
      : (() => {
          const latPad = (mapBounds.north - mapBounds.south) * 0.05;
          const lngPad = (mapBounds.east - mapBounds.west) * 0.05;
          return listings.filter(
            (l) =>
              l.location.lat >= mapBounds.south - latPad &&
              l.location.lat <= mapBounds.north + latPad &&
              l.location.lng >= mapBounds.west - lngPad &&
              l.location.lng <= mapBounds.east + lngPad,
          );
        })();

    if (sortByDistance && userLocation) {
      return [...filtered].sort((a, b) => {
        const da = haversineKm(userLocation.lat, userLocation.lng, a.location.lat, a.location.lng);
        const db = haversineKm(userLocation.lat, userLocation.lng, b.location.lat, b.location.lng);
        return da - db;
      });
    }
    return filtered;
  }, [listings, mapBounds, sortByDistance, userLocation]);

  return (
    <div className="relative overflow-hidden" style={{ height: "calc(100dvh - 64px)" }}>
      {/* List panel */}
      <div
        className={`absolute top-0 left-0 bottom-0 overflow-y-auto scrollbar-hide lg:w-1/2 ${
          mobileView === "map" || mapFullscreen ? "hidden lg:hidden" : "block lg:block right-0 lg:right-auto"
        }`}
      >
        <div className="sticky top-0 z-10 space-y-2 border-b border-neutral-200 bg-white px-4 py-3">
          {/* ÅPNINGSTIDER PAUSET pre-launch — re-aktiver post-launch
          <div className="flex items-center gap-2 overflow-x-auto">
            <Clock className="h-4 w-4 flex-none text-neutral-400" />
            {(["any", "always", "limited"] as const).map((v) => (
              <button
                key={v}
                type="button"
                onClick={() => setOpeningHoursFilter(v)}
                className={`shrink-0 rounded-full border px-3 py-1.5 text-xs font-medium transition-colors ${
                  openingHours === v
                    ? "border-primary-600 bg-primary-50 text-primary-700"
                    : "border-neutral-200 bg-white text-neutral-700 hover:bg-neutral-50"
                }`}
              >
                {tFilter(v)}
              </button>
            ))}
          </div>
          */}
          <div className="flex items-center gap-2 overflow-x-auto">
            <Calendar className="h-4 w-4 flex-none text-neutral-400" />
            {PERIOD_TYPE_OPTIONS.map((p) => {
              const active = activePeriodTypes.has(p);
              return (
                <button
                  key={p}
                  type="button"
                  onClick={() => togglePeriodType(p)}
                  className={`shrink-0 rounded-full border px-3 py-1.5 text-xs font-medium transition-colors ${
                    active
                      ? "border-primary-600 bg-primary-50 text-primary-700"
                      : "border-neutral-200 bg-white text-neutral-700 hover:bg-neutral-50"
                  }`}
                >
                  {PRICE_PACKAGE_PERIOD_LABELS[p]}
                </button>
              );
            })}
          </div>
        </div>
        <SearchResultsList
          listings={visibleListings}
          favoriteIds={favoriteIds}
          onFavoriteToggle={handleFavoriteToggle}
          hoveredListingId={hoveredListingId}
          selectedListingId={selectedListingId}
          onHover={setHoveredListingId}
          onSelect={setSelectedListingId}
          userLocation={userLocation}
          geoStatus={geoStatus}
          onRequestLocation={requestLocation}
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
            aria-label={mapFullscreen ? t("closeFullscreen") : t("fullscreenMap")}
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
            {t("showMap")}
          </>
        ) : (
          <>
            <List className="h-4 w-4" />
            {t("showList")}
          </>
        )}
      </button>
    </div>
  );
}
