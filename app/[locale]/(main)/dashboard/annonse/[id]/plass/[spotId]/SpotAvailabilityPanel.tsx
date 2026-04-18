"use client";

import { useState, useTransition } from "react";
import { DayPicker } from "react-day-picker";
import "react-day-picker/src/style.css";
import { CalendarX2, Save } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { dateFnsLocale } from "@/lib/i18n-helpers";
import { updateSpotBlockedDatesAction } from "@/app/[locale]/(main)/bli-utleier/actions";
import Button from "@/components/ui/Button";

interface Props {
  listingId: string;
  spotId: string;
  initialBlockedDates: string[];
  bookedDates: string[];
}

function dateKey(d: Date) {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export function SpotAvailabilityPanel({ listingId, spotId, initialBlockedDates, bookedDates }: Props) {
  const t = useTranslations("hostStats");
  const locale = useLocale();
  const dfLocale = dateFnsLocale(locale);
  const [blocked, setBlocked] = useState<Set<string>>(new Set(initialBlockedDates));
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [savedAt, setSavedAt] = useState<number | null>(null);

  const bookedSet = new Set(bookedDates);
  const blockedDateObjects = Array.from(blocked).map((d) => new Date(d + "T00:00:00"));
  const bookedDateObjects = bookedDates.map((d) => new Date(d + "T00:00:00"));

  const dirty =
    blocked.size !== initialBlockedDates.length ||
    Array.from(blocked).some((d) => !initialBlockedDates.includes(d));

  const handleDayClick = (day: Date) => {
    const key = dateKey(day);
    if (bookedSet.has(key)) return;
    const next = new Set(blocked);
    if (next.has(key)) next.delete(key);
    else next.add(key);
    setBlocked(next);
  };

  const handleSave = () => {
    setError(null);
    startTransition(async () => {
      const res = await updateSpotBlockedDatesAction(
        listingId,
        spotId,
        Array.from(blocked).sort(),
      );
      if (res.error) {
        setError(res.error);
        return;
      }
      setSavedAt(Date.now());
    });
  };

  return (
    <div>
      <h2 className="text-lg font-semibold text-neutral-900">{t("availabilityTitle")}</h2>
      <p className="mt-1 text-sm text-neutral-500">{t("availabilitySubtitle")}</p>

      <div className="rdp-spot mt-4 inline-block rounded-lg border border-neutral-200 p-3">
        <style>{`
          .rdp-spot .rdp-root {
            --rdp-accent-color: #46c185;
            --rdp-day-height: 40px;
            --rdp-day-width: 40px;
            --rdp-day_button-height: 38px;
            --rdp-day_button-width: 38px;
            --rdp-day_button-border-radius: 8px;
            font-size: 0.875rem;
          }
          .rdp-spot .rdp-blocked {
            background-color: #fee2e2 !important;
            color: #dc2626 !important;
            border-radius: 8px;
          }
          .rdp-spot .rdp-booked {
            background-color: #e0e7ff !important;
            color: #4338ca !important;
            border-radius: 8px;
            cursor: not-allowed;
          }
        `}</style>
        <DayPicker
          onDayClick={handleDayClick}
          disabled={[{ before: new Date() }, ...bookedDateObjects]}
          numberOfMonths={2}
          weekStartsOn={1}
          locale={dfLocale}
          modifiers={{ blocked: blockedDateObjects, booked: bookedDateObjects }}
          modifiersClassNames={{ blocked: "rdp-blocked", booked: "rdp-booked" }}
        />
      </div>

      <div className="mt-3 flex flex-wrap items-center gap-3 text-xs text-neutral-500">
        <span className="inline-flex items-center gap-1">
          <span className="h-2.5 w-2.5 rounded-sm bg-red-100 ring-1 ring-red-200" />
          {t("legendBlocked")}
        </span>
        <span className="inline-flex items-center gap-1">
          <span className="h-2.5 w-2.5 rounded-sm bg-indigo-100 ring-1 ring-indigo-200" />
          {t("legendBooked")}
        </span>
      </div>

      {error && <p className="mt-3 text-sm text-red-600">{error}</p>}

      <div className="mt-4 flex items-center gap-3">
        <Button onClick={handleSave} disabled={!dirty || pending}>
          {pending ? (
            t("saving")
          ) : (
            <span className="inline-flex items-center gap-1.5">
              <Save className="h-3.5 w-3.5" />
              {t("saveBlocked")}
            </span>
          )}
        </Button>
        {savedAt && !dirty && !pending && (
          <span className="text-sm text-green-700">{t("saved")}</span>
        )}
        {blocked.size > 0 && (
          <span className="ml-auto inline-flex items-center gap-1.5 text-sm text-red-700">
            <CalendarX2 className="h-3.5 w-3.5" />
            {t("blockedCount", { count: blocked.size })}
          </span>
        )}
      </div>
    </div>
  );
}
