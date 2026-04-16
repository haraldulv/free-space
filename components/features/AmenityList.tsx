"use client";

import {
  Zap,
  Umbrella,
  Camera,
  Lock,
  Lightbulb,
  Bath,
  Droplets,
  Wifi,
  Flame,
  Waves,
  Mountain,
  PawPrint,
  Trash2,
  ShowerHead,
  Accessibility,
} from "lucide-react";
import { useTranslations } from "next-intl";
import { Amenity } from "@/types";

export const amenityIcons: Record<Amenity, React.ElementType> = {
  ev_charging: Zap,
  covered: Umbrella,
  security_camera: Camera,
  gated: Lock,
  lighting: Lightbulb,
  toilets: Bath,
  showers: ShowerHead,
  electricity: Zap,
  water: Droplets,
  wifi: Wifi,
  campfire: Flame,
  lake_access: Waves,
  mountain_view: Mountain,
  pets_allowed: PawPrint,
  waste_disposal: Trash2,
  handicap_accessible: Accessibility,
};

// Backward-compatible export for components that want {label, icon} objects.
// Call from a client component and pass t() for labels.
export function useAmenityConfig(): Record<Amenity, { label: string; icon: React.ElementType }> {
  const t = useTranslations("amenity");
  return (Object.keys(amenityIcons) as Amenity[]).reduce((acc, key) => {
    acc[key] = { label: t(key), icon: amenityIcons[key] };
    return acc;
  }, {} as Record<Amenity, { label: string; icon: React.ElementType }>);
}

interface AmenityListProps {
  amenities: Amenity[];
}

export default function AmenityList({ amenities }: AmenityListProps) {
  const t = useTranslations("amenity");
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
      {amenities.map((amenity) => {
        const Icon = amenityIcons[amenity];
        return (
          <div
            key={amenity}
            className="flex items-center gap-2.5 rounded-lg border border-neutral-100 bg-neutral-50 px-3 py-2.5"
          >
            <Icon className="h-4 w-4 shrink-0 text-primary-600" />
            <span className="text-sm text-neutral-700">{t(amenity)}</span>
          </div>
        );
      })}
    </div>
  );
}
