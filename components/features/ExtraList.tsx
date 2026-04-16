"use client";

import {
  Zap,
  Plug,
  Trash2,
  Flame,
  TreePine,
  Waves,
  Bike,
  Fish,
  Bed,
  UtensilsCrossed,
  Sparkles,
} from "lucide-react";
import { useTranslations } from "next-intl";
import type { ExtraId, ListingExtra } from "@/types";

const extraIconMap: Record<ExtraId, React.ElementType> = {
  ev_charging: Zap,
  power_hookup: Plug,
  septic_disposal: Trash2,
  sauna: Flame,
  firewood: TreePine,
  kayak: Waves,
  bike_rental: Bike,
  fishing_gear: Fish,
  bedding: Bed,
  grill: UtensilsCrossed,
};

function iconFor(id: string): React.ElementType {
  return extraIconMap[id as ExtraId] ?? Sparkles;
}

interface ExtraListProps {
  extras: ListingExtra[];
}

export default function ExtraList({ extras }: ExtraListProps) {
  const t = useTranslations("booking");
  if (extras.length === 0) return null;
  return (
    <div className="space-y-2">
      {extras.map((ex) => {
        const Icon = iconFor(ex.id);
        return (
          <div
            key={ex.id}
            className="flex items-center justify-between gap-3 rounded-lg border border-neutral-200 bg-white px-3 py-2.5"
          >
            <div className="flex items-center gap-2.5">
              <Icon className="h-4 w-4 shrink-0 text-primary-600" />
              <span className="text-sm font-medium text-neutral-800">{ex.name}</span>
            </div>
            <span className="text-sm text-neutral-500 whitespace-nowrap">
              {ex.perNight ? t("pricePerNightShort", { price: ex.price }) : `${ex.price} kr`}
            </span>
          </div>
        );
      })}
    </div>
  );
}
