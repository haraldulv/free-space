"use client";

import { useTranslations } from "next-intl";
import Input from "@/components/ui/Input";
import Textarea from "@/components/ui/Textarea";
import Toggle from "@/components/ui/Toggle";
import type { ListingCategory } from "@/types";

interface BasicInfoStepProps {
  title: string;
  description: string;
  spots: number;
  maxVehicleLength?: number;
  category?: ListingCategory;
  checkInTime?: string;
  checkOutTime?: string;
  instantBooking: boolean;
  onChange: (field: string, value: string | number | boolean | undefined) => void;
  errors: Record<string, string>;
}

export default function BasicInfoStep({
  title,
  description,
  spots,
  maxVehicleLength,
  category,
  checkInTime,
  checkOutTime,
  instantBooking,
  onChange,
  errors,
}: BasicInfoStepProps) {
  const t = useTranslations("host.basicInfo");
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-neutral-900">{t("title")}</h2>
        <p className="mt-1 text-sm text-neutral-500">{t("subtitle")}</p>
      </div>

      <Input
        id="title"
        label={t("titleLabel")}
        placeholder={t("titlePlaceholder")}
        value={title}
        onChange={(e) => onChange("title", e.target.value)}
        error={errors.title}
      />

      <Textarea
        id="description"
        label={t("descriptionLabel")}
        placeholder={t("descriptionPlaceholder")}
        rows={4}
        value={description}
        onChange={(e) => onChange("description", e.target.value)}
        error={errors.description}
      />

      <div className="grid gap-4 sm:grid-cols-2">
        <Input
          id="spots"
          label={t("spotsLabel")}
          type="number"
          min={1}
          max={100}
          value={spots || ""}
          onChange={(e) => onChange("spots", parseInt(e.target.value) || 0)}
          error={errors.spots}
        />

        {category === "camping" && (
          <Input
            id="maxVehicleLength"
            label={t("maxVehicleLengthLabel")}
            type="number"
            min={1}
            max={30}
            placeholder={t("maxVehicleLengthPlaceholder")}
            value={maxVehicleLength || ""}
            onChange={(e) => {
              const val = e.target.value ? parseInt(e.target.value) : undefined;
              onChange("maxVehicleLength", val);
            }}
            error={errors.maxVehicleLength}
          />
        )}
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <Input
          id="checkInTime"
          label={t("checkInLabel")}
          type="time"
          value={checkInTime || "15:00"}
          onChange={(e) => onChange("checkInTime", e.target.value)}
          error={errors.checkInTime}
        />
        <Input
          id="checkOutTime"
          label={t("checkOutLabel")}
          type="time"
          value={checkOutTime || "11:00"}
          onChange={(e) => onChange("checkOutTime", e.target.value)}
          error={errors.checkOutTime}
        />
      </div>

      <div className="rounded-xl border border-neutral-200 p-4">
        <Toggle
          checked={instantBooking}
          onChange={(v) => onChange("instantBooking", v)}
          label={t("instantLabel")}
          description={t("instantDesc")}
        />
      </div>
    </div>
  );
}
