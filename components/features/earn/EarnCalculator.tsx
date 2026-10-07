"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";
import {
  PARKING_AREAS,
  estimateEarnings,
  type AvailabilityKind,
  type SpotKind,
} from "@/lib/parking-rates";

const nok = new Intl.NumberFormat("nb-NO");

function PillRow<T extends string>({
  options,
  value,
  onChange,
}: {
  options: { id: T; label: string }[];
  value: T;
  onChange: (id: T) => void;
}) {
  return (
    <div className="flex flex-wrap gap-2">
      {options.map((opt) => {
        const active = opt.id === value;
        return (
          <button
            key={opt.id}
            type="button"
            onClick={() => onChange(opt.id)}
            className={`rounded-full px-4 py-2.5 text-sm font-semibold transition-colors ${
              active
                ? "bg-neutral-900 text-white"
                : "bg-neutral-100 text-neutral-700 hover:bg-neutral-200"
            }`}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}

export default function EarnCalculator() {
  const t = useTranslations("tjen");
  const [areaId, setAreaId] = useState(PARKING_AREAS[0].id);
  const [kind, setKind] = useState<SpotKind>("outdoor");
  const [availability, setAvailability] = useState<AvailabilityKind>("always");

  const estimate = useMemo(
    () => estimateEarnings(areaId, kind, availability),
    [areaId, kind, availability],
  );

  return (
    <div className="rounded-3xl bg-[#fdfcf9] p-6 shadow-[0_18px_50px_rgba(18,20,18,0.18)] sm:p-8">
      <h2 className="text-xl font-bold text-neutral-900 sm:text-2xl">{t("calcTitle")}</h2>

      <div className="mt-5 space-y-5">
        <div>
          <label htmlFor="earn-area" className="mb-2 block text-sm font-semibold text-neutral-700">
            {t("areaLabel")}
          </label>
          <select
            id="earn-area"
            value={areaId}
            onChange={(e) => setAreaId(e.target.value)}
            className="w-full appearance-none rounded-2xl border border-neutral-200 bg-white px-4 py-3 text-[15px] font-medium text-neutral-900 focus:border-[#37caa4] focus:outline-none"
          >
            {PARKING_AREAS.map((area) => (
              <option key={area.id} value={area.id}>
                {t(area.nameKey)}
              </option>
            ))}
          </select>
        </div>

        <div>
          <p className="mb-2 text-sm font-semibold text-neutral-700">{t("kindLabel")}</p>
          <PillRow
            options={[
              { id: "outdoor" as SpotKind, label: t("kindOutdoor") },
              { id: "carport" as SpotKind, label: t("kindCarport") },
              { id: "garage" as SpotKind, label: t("kindGarage") },
            ]}
            value={kind}
            onChange={setKind}
          />
        </div>

        <div>
          <p className="mb-2 text-sm font-semibold text-neutral-700">{t("availLabel")}</p>
          <PillRow
            options={[
              { id: "always" as AvailabilityKind, label: t("availAlways") },
              { id: "weekdays" as AvailabilityKind, label: t("availWeekdays") },
              { id: "weekends" as AvailabilityKind, label: t("availWeekends") },
            ]}
            value={availability}
            onChange={setAvailability}
          />
        </div>
      </div>

      <div className="mt-6 rounded-2xl bg-[#121412] px-6 py-5 text-[#f5f6f4]">
        <p className="text-xs font-bold uppercase tracking-wide text-[#a8afaa]">
          {t("estimateTitle")}
        </p>
        <p className="mt-1 text-3xl font-bold text-[#37caa4] sm:text-4xl">
          {t("estimateRange", { low: nok.format(estimate.monthLow), high: nok.format(estimate.monthHigh) })}
        </p>
        <p className="mt-2 text-sm font-medium text-[#cfd4d0]">
          {t("estimateDay", { low: nok.format(estimate.dayLow), high: nok.format(estimate.dayHigh) })}
        </p>
      </div>

      <p className="mt-4 text-xs leading-relaxed text-neutral-500">{t("estimateNote")}</p>
    </div>
  );
}
