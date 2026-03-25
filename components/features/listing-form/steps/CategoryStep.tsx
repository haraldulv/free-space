"use client";

import { Car, Tent, Bus, Caravan } from "lucide-react";
import type { ListingCategory, VehicleType } from "@/types";
import { vehicleLabels } from "@/types";

interface CategoryStepProps {
  value?: ListingCategory;
  vehicleType?: VehicleType;
  onChange: (category: ListingCategory) => void;
  onVehicleChange: (vehicleType: VehicleType) => void;
  error?: string;
  vehicleError?: string;
}

const categories: { id: ListingCategory; label: string; description: string; icon: React.ElementType }[] = [
  {
    id: "parking",
    label: "Parkering",
    description: "Parkeringsplass for biler, el-biler eller varebiler",
    icon: Car,
  },
  {
    id: "camping",
    label: "Camping / Bobil",
    description: "Camping-, bobil- eller oppstillingsplass med fasiliteter",
    icon: Tent,
  },
];

const vehicleOptions: { id: VehicleType; icon: React.ElementType }[] = [
  { id: "motorhome", icon: Bus },
  { id: "campervan", icon: Caravan },
  { id: "car", icon: Car },
];

export default function CategoryStep({ value, vehicleType, onChange, onVehicleChange, error, vehicleError }: CategoryStepProps) {
  return (
    <div className="space-y-8">
      <div className="space-y-6">
        <div>
          <h2 className="text-xl font-bold text-neutral-900">Hva slags plass leier du ut?</h2>
          <p className="mt-1 text-sm text-neutral-500">Velg kategorien som passer best</p>
        </div>

        {error && <p className="text-sm text-red-500">{error}</p>}

        <div className="grid gap-4 sm:grid-cols-2">
          {categories.map(({ id, label, description, icon: Icon }) => (
            <button
              key={id}
              type="button"
              onClick={() => onChange(id)}
              className={`flex flex-col items-start gap-3 rounded-xl border-2 p-6 text-left transition-all ${
                value === id
                  ? "border-primary-600 bg-primary-50 shadow-sm"
                  : "border-neutral-200 hover:border-neutral-300 hover:shadow-sm"
              }`}
            >
              <Icon className={`h-8 w-8 ${value === id ? "text-primary-600" : "text-neutral-400"}`} />
              <div>
                <h3 className="text-base font-semibold text-neutral-900">{label}</h3>
                <p className="mt-0.5 text-sm text-neutral-500">{description}</p>
              </div>
            </button>
          ))}
        </div>
      </div>

      <div className="space-y-4">
        <div>
          <h3 className="text-lg font-semibold text-neutral-900">Hvilken kjøretøystype passer?</h3>
          <p className="mt-1 text-sm text-neutral-500">Velg den største kjøretøystypen plassen er egnet for</p>
        </div>

        {vehicleError && <p className="text-sm text-red-500">{vehicleError}</p>}

        <div className="grid gap-3 sm:grid-cols-3">
          {vehicleOptions.map(({ id, icon: Icon }) => {
            const selected = vehicleType === id;
            return (
              <button
                key={id}
                type="button"
                onClick={() => onVehicleChange(id)}
                className={`flex items-center gap-3 rounded-xl border-2 px-4 py-4 text-left transition-all ${
                  selected
                    ? "border-primary-600 bg-primary-50 shadow-sm"
                    : "border-neutral-200 hover:border-neutral-300 hover:shadow-sm"
                }`}
              >
                <Icon className={`h-6 w-6 shrink-0 ${selected ? "text-primary-600" : "text-neutral-400"}`} />
                <span className={`text-sm font-medium ${selected ? "text-neutral-900" : "text-neutral-600"}`}>
                  {vehicleLabels[id]}
                </span>
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
