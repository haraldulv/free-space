"use client";

import {
  Car,
  Tent,
  LayoutGrid,
  Zap,
  Warehouse,
  Waves,
  Mountain,
  PawPrint,
} from "lucide-react";
import { ListingCategory } from "@/types";

interface CategoryTabsProps {
  selected?: ListingCategory;
  onChange: (category?: ListingCategory) => void;
}

const categories: {
  value?: ListingCategory;
  label: string;
  icon: React.ElementType;
}[] = [
  { value: undefined, label: "Alle", icon: LayoutGrid },
  { value: "parking", label: "Parkering", icon: Car },
  { value: "camping", label: "Campingplass", icon: Tent },
  { value: undefined, label: "EV-lading", icon: Zap },
  { value: undefined, label: "Overbygget", icon: Warehouse },
  { value: undefined, label: "Ved sjøen", icon: Waves },
  { value: undefined, label: "Fjellutsikt", icon: Mountain },
  { value: undefined, label: "Dyrevennlig", icon: PawPrint },
];

export default function CategoryTabs({
  selected,
  onChange,
}: CategoryTabsProps) {
  return (
    <div className="relative">
      <div className="flex items-center gap-8 overflow-x-auto py-4 scrollbar-hide">
        {categories.map((cat, i) => {
          const isActive =
            i < 3
              ? selected === cat.value
              : false;
          const Icon = cat.icon;
          const isClickable = i < 3;

          return (
            <button
              key={cat.label}
              onClick={() => isClickable && onChange(cat.value)}
              className={`flex flex-col items-center gap-1.5 shrink-0 pb-2 transition-all border-b-2 ${
                isActive
                  ? "border-neutral-900 opacity-100"
                  : "border-transparent opacity-60 hover:opacity-80 hover:border-neutral-300"
              } ${!isClickable ? "cursor-default" : ""}`}
            >
              <Icon className="h-6 w-6" />
              <span className="text-xs font-medium whitespace-nowrap">
                {cat.label}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
