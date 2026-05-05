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

      <Input
        id="price"
        label={priceUnit === "time" ? t("priceLabelDay") : t("priceLabelNight")}
        type="number"
        min={1}
        placeholder={t("pricePlaceholder")}
        value={price || ""}
        onChange={(e) => onChange("price", parseInt(e.target.value) || 0)}
        error={errors.price}
      />

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
