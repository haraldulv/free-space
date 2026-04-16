"use client";

import { useState } from "react";
import { Zap, Plug, Droplets, Flame, TreePine, Ship, Bike, Fish, BedDouble, UtensilsCrossed, Sparkles, X } from "lucide-react";
import { useTranslations } from "next-intl";
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
  const t = useTranslations("host.extras");
  const te = useTranslations("extra");
  const available = AVAILABLE_EXTRAS.filter((e) => e.category.includes(category) && e.scope === "area");
  const presetIds = new Set(AVAILABLE_EXTRAS.map((e) => e.id));
  const customExtras = extras.filter((e) => !presetIds.has(e.id as ExtraId));

  const [customName, setCustomName] = useState("");
  const [customPrice, setCustomPrice] = useState("");
  const [customPerNight, setCustomPerNight] = useState(false);

  const addCustom = () => {
    const name = customName.trim();
    const price = Number(customPrice);
    if (!name || !price || price <= 0) return;
    onChange([
      ...extras,
      { id: crypto.randomUUID(), name, price, perNight: customPerNight },
    ]);
    setCustomName("");
    setCustomPrice("");
    setCustomPerNight(false);
  };

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
        <h2 className="text-xl font-bold text-neutral-900">{t("title")}</h2>
        <p className="mt-1 text-sm text-neutral-500">{t("subtitle")}</p>
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
                    {te(extra.id)}
                  </span>
                  <span className="ml-2 text-xs text-neutral-400">
                    {extra.perNight ? t("perNight") : t("oneTime")}
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
                      label={t("priceLabel")}
                      type="number"
                      value={String(selected.price)}
                      onChange={(e) => updatePrice(extra.id, Math.max(0, Number(e.target.value)))}
                      className="w-32"
                    />
                    <span className="mt-5 text-sm text-neutral-500">{extra.perNight ? t("pricePerNightUnit") : t("priceOneTimeUnit")}</span>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {available.length === 0 && (
        <p className="text-sm text-neutral-400">{t("noneAvailable")}</p>
      )}

      <div className="space-y-3 pt-4 border-t border-neutral-200">
        <div>
          <h3 className="text-base font-semibold text-neutral-900">{t("customHeader")}</h3>
          <p className="mt-1 text-xs text-neutral-500">{t("customSubtitle")}</p>
        </div>

        {customExtras.map((extra) => (
          <div key={extra.id} className="flex items-center gap-3 rounded-lg bg-primary-50 px-3 py-2">
            <Sparkles className="h-4 w-4 text-primary-600" />
            <div className="flex-1">
              <div className="text-sm font-medium text-neutral-900">{extra.name}</div>
              <div className="text-xs text-neutral-500">
                {extra.price} {extra.perNight ? t("pricePerNightUnit") : t("priceOneTimeUnit")}
              </div>
            </div>
            <button
              type="button"
              onClick={() => onChange(extras.filter((e) => e.id !== extra.id))}
              className="text-neutral-400 hover:text-neutral-600"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        ))}

        <div className="flex gap-2">
          <input
            type="text"
            value={customName}
            onChange={(e) => setCustomName(e.target.value)}
            placeholder={t("customNamePlaceholder")}
            className="flex-1 rounded-lg border border-neutral-300 px-3 py-2 text-sm"
          />
          <input
            type="number"
            value={customPrice}
            onChange={(e) => setCustomPrice(e.target.value)}
            placeholder={t("customPricePlaceholder")}
            className="w-24 rounded-lg border border-neutral-300 px-3 py-2 text-sm"
          />
        </div>
        <div className="flex items-center gap-3">
          <label className="flex items-center gap-2 text-sm text-neutral-600">
            <input
              type="checkbox"
              checked={customPerNight}
              onChange={(e) => setCustomPerNight(e.target.checked)}
              className="h-4 w-4 rounded border-neutral-300"
            />
            {t("customPerNightLabel")}
          </label>
          <button
            type="button"
            onClick={addCustom}
            disabled={!customName.trim() || Number(customPrice) <= 0}
            className="ml-auto rounded-full bg-primary-600 px-4 py-2 text-sm font-semibold text-white disabled:bg-neutral-300"
          >
            {t("addButton")}
          </button>
        </div>
      </div>
    </div>
  );
}
