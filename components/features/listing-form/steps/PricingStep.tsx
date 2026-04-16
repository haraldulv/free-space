"use client";

import { useTranslations } from "next-intl";
import Input from "@/components/ui/Input";
import Toggle from "@/components/ui/Toggle";

interface PricingStepProps {
  price: number;
  priceUnit: "time" | "natt";
  instantBooking: boolean;
  onChange: (field: string, value: string | number | boolean) => void;
  errors: Record<string, string>;
}

export default function PricingStep({
  price,
  priceUnit,
  instantBooking,
  onChange,
  errors,
}: PricingStepProps) {
  const t = useTranslations("host.pricing");
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-neutral-900">{t("title")}</h2>
        <p className="mt-1 text-sm text-neutral-500">{t("subtitle")}</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Input
          id="price"
          label={t("priceLabel")}
          type="number"
          min={1}
          placeholder={t("pricePlaceholder")}
          value={price || ""}
          onChange={(e) => onChange("price", parseInt(e.target.value) || 0)}
          error={errors.price}
        />

        <div className="space-y-1">
          <label className="block text-sm font-medium text-neutral-700">{t("priceUnitLabel")}</label>
          <div className="flex gap-2">
            {(["time", "natt"] as const).map((unit) => (
              <button
                key={unit}
                type="button"
                onClick={() => onChange("priceUnit", unit)}
                className={`flex-1 rounded-lg border-2 px-4 py-2.5 text-sm font-medium transition-all ${
                  priceUnit === unit
                    ? "border-primary-600 bg-primary-50 text-primary-700"
                    : "border-neutral-200 text-neutral-600 hover:border-neutral-300"
                }`}
              >
                {unit === "time" ? t("perHour") : t("perNight")}
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="rounded-xl border border-neutral-200 p-4">
        <Toggle
          checked={instantBooking}
          onChange={(val) => onChange("instantBooking", val)}
          label={t("instantLabel")}
          description={t("instantDesc")}
        />
      </div>
    </div>
  );
}
