"use client";

import { Navigation } from "lucide-react";
import { useLocale } from "next-intl";
import { haversineKm, formatDistance } from "@/lib/geo";
import { useUserLocation } from "@/lib/hooks/useUserLocation";

interface ListingDistanceBadgeProps {
  lat: number;
  lng: number;
}

/**
 * Viser avstand fra brukerens kjente posisjon til annonsen.
 * Returnerer null hvis bruker ikke har delt posisjon.
 */
export default function ListingDistanceBadge({ lat, lng }: ListingDistanceBadgeProps) {
  const locale = useLocale();
  const { location } = useUserLocation();

  if (!location) return null;

  const km = haversineKm(location.lat, location.lng, lat, lng);

  return (
    <span className="flex items-center gap-1">
      <Navigation className="h-4 w-4" />
      {formatDistance(km, locale)}
    </span>
  );
}
