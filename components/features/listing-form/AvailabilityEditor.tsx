"use client";

import { CalendarX2 } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { dateFnsLocale } from "@/lib/i18n-helpers";
import TunoCalendar from "@/components/ui/TunoCalendar";

interface AvailabilityEditorProps {
  blockedDates: string[];
  onChange: (dates: string[]) => void;
  saving?: boolean;
}

export default function AvailabilityEditor({ blockedDates, onChange }: AvailabilityEditorProps) {
  const t = useTranslations("host.availability");
  const locale = useLocale();
  const dfLocale = dateFnsLocale(locale);
  const blocked = new Set(blockedDates);

  const blockedDateObjects = blockedDates.map((d) => new Date(d + "T00:00:00"));

  const handleDayClick = (day: Date) => {
    const key = `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, "0")}-${String(day.getDate()).padStart(2, "0")}`;
    const next = new Set(blocked);
    if (next.has(key)) {
      next.delete(key);
    } else {
      next.add(key);
    }
    onChange(Array.from(next).sort());
  };

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-semibold text-neutral-900">{t("title")}</h3>
        <p className="mt-1 text-sm text-neutral-500">
          {t("subtitle")}
        </p>
      </div>

      <div className="inline-block rounded-lg border border-neutral-200 p-3">
        <TunoCalendar
          onDayClick={handleDayClick}
          disabled={{ before: new Date() }}
          numberOfMonths={2}
          locale={dfLocale}
          modifiers={{ blocked: blockedDateObjects }}
          modifiersClassNames={{ blocked: "rdp-blocked" }}
        />
      </div>

      {blocked.size > 0 && (
        <div className="flex items-start gap-2 rounded-lg bg-red-50 p-3">
          <CalendarX2 className="h-4 w-4 text-red-500 mt-0.5 shrink-0" />
          <p className="text-sm text-red-700">
            {t("blockedCount", { count: blocked.size })}
          </p>
        </div>
      )}
    </div>
  );
}
