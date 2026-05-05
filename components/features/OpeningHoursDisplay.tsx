"use client";

import { useTranslations } from "next-intl";
import { Clock } from "lucide-react";
import type { OpeningHours, Weekday } from "@/types";
import { WEEKDAYS } from "@/types";

interface OpeningHoursDisplayProps {
  hours: OpeningHours | null | undefined;
  /** Hvis true, vis kompakt — én linje. Default: full grid. */
  compact?: boolean;
  /** Vis ikke noe når plassen er døgnåpent. Default false. */
  hideWhenAlwaysOpen?: boolean;
}

export default function OpeningHoursDisplay({ hours, compact, hideWhenAlwaysOpen }: OpeningHoursDisplayProps) {
  const t = useTranslations("openingHours");
  const tDay = useTranslations("openingHours.day");

  if (!hours) {
    if (hideWhenAlwaysOpen) return null;
    return (
      <div className="flex items-center gap-2 text-sm text-neutral-700">
        <Clock className="h-4 w-4 text-neutral-400" />
        <span>{t("alwaysOpen")}</span>
      </div>
    );
  }

  const formatRange = (day: Weekday): string => {
    const v = hours[day];
    if (!v) return t("closed");
    return v.replace("-", "–");
  };

  if (compact) {
    return (
      <div className="flex items-center gap-2 text-sm text-amber-800">
        <Clock className="h-4 w-4" />
        <span className="font-medium">{t("limitedHours")}</span>
      </div>
    );
  }

  return (
    <div className="space-y-1 text-sm">
      {WEEKDAYS.map((day) => {
        const v = hours[day];
        const closed = !v;
        return (
          <div key={day} className="flex justify-between gap-3">
            <span className="font-medium text-neutral-700">{tDay(day)}</span>
            <span className={closed ? "text-neutral-400" : "text-neutral-900"}>{formatRange(day)}</span>
          </div>
        );
      })}
    </div>
  );
}
