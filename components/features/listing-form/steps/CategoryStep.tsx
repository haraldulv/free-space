"use client";

import { Car, Tent } from "lucide-react";
import type { ListingCategory } from "@/types";

interface CategoryStepProps {
  value?: ListingCategory;
  onChange: (category: ListingCategory) => void;
  error?: string;
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

export default function CategoryStep({ value, onChange, error }: CategoryStepProps) {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-neutral-900">Hva slags plass leier du ut?</h2>
        <p className="mt-1 text-sm text-neutral-500">Velg kategorien som passer best</p>
      </div>

      {error && (
        <p className="text-sm text-red-500">{error}</p>
      )}

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
  );
}
