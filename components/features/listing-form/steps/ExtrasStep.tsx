"use client";

import { Zap, Plug, Droplets, Flame, TreePine, Ship, Bike, Fish, BedDouble, UtensilsCrossed } from "lucide-react";
import { AVAILABLE_EXTRAS, type ListingCategory, type ListingExtra, type ExtraId } from "@/types";
import Input from "@/components/ui/Input";

const extraIcons: Record<ExtraId, React.ElementType> = {
  ev_charging: Zap,
  power_hookup: Plug,
  septic_disposal: Droplets,
  sauna: Flame,
  firewood: TreePine,
  kayak: Ship,
  bike_rental: Bike,
  fishing_gear: Fish,
  bedding: BedDouble,
  grill: UtensilsCrossed,
};

interface ExtrasStepProps {
  category: ListingCategory;
  extras: ListingExtra[];
  onChange: (extras: ListingExtra[]) => void;
}

export default function ExtrasStep({ category, extras, onChange }: ExtrasStepProps) {
  const available = AVAILABLE_EXTRAS.filter((e) => e.category.includes(category));

  const toggle = (extraId: ExtraId) => {
    const existing = extras.find((e) => e.id === extraId);
    if (existing) {
      onChange(extras.filter((e) => e.id !== extraId));
    } else {
      const def = AVAILABLE_EXTRAS.find((e) => e.id === extraId)!;
      onChange([...extras, { id: extraId, name: def.name, price: def.defaultPrice, perNight: def.perNight }]);
    }
  };

  const updatePrice = (extraId: string, price: number) => {
    onChange(extras.map((e) => e.id === extraId ? { ...e, price } : e));
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-neutral-900">Tilleggstjenester</h2>
        <p className="mt-1 text-sm text-neutral-500">Tilby ekstra tjenester mot betaling. Du bestemmer prisen selv.</p>
      </div>

      <div className="space-y-3">
        {available.map((extra) => {
          const Icon = extraIcons[extra.id];
          const selected = extras.find((e) => e.id === extra.id);
          const isSelected = !!selected;

          return (
            <div key={extra.id} className={`rounded-lg border-2 transition-all ${isSelected ? "border-primary-600 bg-primary-50" : "border-neutral-200"}`}>
              <button
                type="button"
                onClick={() => toggle(extra.id)}
                className="flex w-full items-center gap-3 px-4 py-3 text-left"
              >
                <Icon className={`h-5 w-5 shrink-0 ${isSelected ? "text-primary-600" : "text-neutral-400"}`} />
                <div className="flex-1">
                  <span className={`text-sm ${isSelected ? "font-medium text-neutral-900" : "text-neutral-600"}`}>
                    {extra.name}
                  </span>
                  <span className="ml-2 text-xs text-neutral-400">
                    {extra.perNight ? "per natt" : "engangspris"}
                  </span>
                </div>
                <div className={`flex h-5 w-5 items-center justify-center rounded border-2 ${isSelected ? "border-primary-600 bg-primary-600" : "border-neutral-300"}`}>
                  {isSelected && <svg className="h-3 w-3 text-white" viewBox="0 0 12 12"><path d="M10 3L4.5 8.5L2 6" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
                </div>
              </button>
              {isSelected && (
                <div className="border-t border-primary-200 px-4 py-3">
                  <div className="flex items-center gap-3">
                    <Input
                      id={`price-${extra.id}`}
                      label="Pris (kr)"
                      type="number"
                      value={String(selected.price)}
                      onChange={(e) => updatePrice(extra.id, Math.max(0, Number(e.target.value)))}
                      className="w-32"
                    />
                    <span className="mt-5 text-sm text-neutral-500">{extra.perNight ? "kr/natt" : "kr (engangspris)"}</span>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {available.length === 0 && (
        <p className="text-sm text-neutral-400">Ingen tilleggstjenester tilgjengelig for denne kategorien</p>
      )}
    </div>
  );
}
