"use client";

import { useTranslations } from "next-intl";
import { Clock } from "lucide-react";
import type { OpeningHours, Weekday } from "@/types";
import { WEEKDAYS } from "@/types";
import { DEFAULT_LIMITED_HOURS, parseOpeningRange } from "@/lib/opening-hours";

interface OpeningHoursEditorProps {
  value: OpeningHours | null | undefined;
  onChange: (next: OpeningHours | null) => void;
}

const HOUR_OPTIONS: string[] = (() => {
  const out: string[] = [];
  for (let h = 0; h < 24; h++) {
    out.push(`${String(h).padStart(2, "0")}:00`);
    out.push(`${String(h).padStart(2, "0")}:30`);
  }
  return out;
})();

export default function OpeningHoursEditor({ value, onChange }: OpeningHoursEditorProps) {
  const t = useTranslations("openingHours");
  const tDay = useTranslations("openingHours.day");
  const isLimited = value !== null && value !== undefined;

  function setMode(limited: boolean) {
    if (limited) {
      onChange(value && Object.keys(value).length > 0 ? value : { ...DEFAULT_LIMITED_HOURS });
    } else {
      onChange(null);
    }
  }

  function setDayValue(day: Weekday, range: string | null) {
    onChange({ ...(value || {}), [day]: range });
  }

  function getRange(day: Weekday): { start: string; end: string } | null {
    const v = value?.[day];
    if (!v) return null;
    const parsed = parseOpeningRange(v);
    if (!parsed) return null;
    const fmt = (mins: number) => `${String(Math.floor(mins / 60)).padStart(2, "0")}:${String(mins % 60).padStart(2, "0")}`;
    return { start: fmt(parsed.start), end: fmt(parsed.end) };
  }

  return (
    <div className="space-y-4">
      <div className="flex gap-2">
        <button
          type="button"
          onClick={() => setMode(false)}
          className={`flex-1 rounded-lg border-2 px-4 py-3 text-left transition-all ${
            !isLimited ? "border-primary-600 bg-primary-50" : "border-neutral-200 hover:border-neutral-300"
          }`}
        >
          <div className="flex items-center gap-2 font-medium text-neutral-900">
            <Clock className="h-4 w-4" /> {t("alwaysOpen")}
          </div>
          <p className="mt-0.5 text-xs text-neutral-500">{t("alwaysOpenHint")}</p>
        </button>
        <button
          type="button"
          onClick={() => setMode(true)}
          className={`flex-1 rounded-lg border-2 px-4 py-3 text-left transition-all ${
            isLimited ? "border-primary-600 bg-primary-50" : "border-neutral-200 hover:border-neutral-300"
          }`}
        >
          <div className="flex items-center gap-2 font-medium text-neutral-900">
            <Clock className="h-4 w-4" /> {t("limitedHours")}
          </div>
          <p className="mt-0.5 text-xs text-neutral-500">{t("limitedHoursHint")}</p>
        </button>
      </div>

      {isLimited && (
        <div className="space-y-2 rounded-xl border border-neutral-200 p-4">
          {WEEKDAYS.map((day) => {
            const range = getRange(day);
            const closed = value?.[day] === null || value?.[day] === undefined;
            return (
              <div key={day} className="flex items-center gap-3">
                <label className="w-24 text-sm font-medium text-neutral-700">
                  {tDay(day)}
                </label>
                <button
                  type="button"
                  onClick={() => setDayValue(day, closed ? "09:00-17:00" : null)}
                  className={`rounded-md border px-3 py-1.5 text-xs font-medium transition-colors ${
                    closed ? "border-neutral-200 bg-neutral-50 text-neutral-500" : "border-primary-600 bg-primary-50 text-primary-700"
                  }`}
                >
                  {closed ? t("closed") : t("open")}
                </button>
                {!closed && range && (
                  <div className="flex flex-1 items-center gap-2">
                    <select
                      value={range.start}
                      onChange={(e) => setDayValue(day, `${e.target.value}-${range.end}`)}
                      className="flex-1 rounded-md border border-neutral-300 bg-white px-2 py-1.5 text-sm"
                    >
                      {HOUR_OPTIONS.map((h) => (
                        <option key={h} value={h}>{h}</option>
                      ))}
                    </select>
                    <span className="text-neutral-400">–</span>
                    <select
                      value={range.end}
                      onChange={(e) => setDayValue(day, `${range.start}-${e.target.value}`)}
                      className="flex-1 rounded-md border border-neutral-300 bg-white px-2 py-1.5 text-sm"
                    >
                      {HOUR_OPTIONS.map((h) => (
                        <option key={h} value={h}>{h}</option>
                      ))}
                    </select>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
