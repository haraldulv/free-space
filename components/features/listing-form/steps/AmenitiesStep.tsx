"use client";

import { AMENITIES_BY_CATEGORY, type Amenity, type ListingCategory } from "@/types";
import { amenityConfig } from "@/components/features/AmenityList";

interface AmenitiesStepProps {
  category: ListingCategory;
  selected: Amenity[];
  onChange: (amenities: Amenity[]) => void;
}

export default function AmenitiesStep({ category, selected, onChange }: AmenitiesStepProps) {
  const available = AMENITIES_BY_CATEGORY[category] || [];

  const toggle = (amenity: Amenity) => {
    if (selected.includes(amenity)) {
      onChange(selected.filter((a) => a !== amenity));
    } else {
      onChange([...selected, amenity]);
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-neutral-900">Hvilke fasiliteter tilbyr du?</h2>
        <p className="mt-1 text-sm text-neutral-500">Velg alt som er tilgjengelig for gjestene</p>
      </div>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
        {available.map((amenity) => {
          const config = amenityConfig[amenity];
          const Icon = config.icon;
          const isSelected = selected.includes(amenity);

          return (
            <button
              key={amenity}
              type="button"
              onClick={() => toggle(amenity)}
              className={`flex items-center gap-2.5 rounded-lg border-2 px-3 py-3 text-left transition-all ${
                isSelected
                  ? "border-primary-600 bg-primary-50"
                  : "border-neutral-200 hover:border-neutral-300"
              }`}
            >
              <Icon className={`h-5 w-5 shrink-0 ${isSelected ? "text-primary-600" : "text-neutral-400"}`} />
              <span className={`text-sm ${isSelected ? "font-medium text-neutral-900" : "text-neutral-600"}`}>
                {config.label}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
