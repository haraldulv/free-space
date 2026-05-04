"use client";

import { useMemo, useState } from "react";
import { Sparkles, Info } from "lucide-react";
import { useTranslations } from "next-intl";
import type { SpotMarker } from "@/types";

interface DiscountsStepProps {
  spotMarkers: SpotMarker[];
  defaultPrice: number;
  onChange: (field: string, value: unknown) => void;
}

interface DiscountTrio {
  day: number | null;
  week: number | null;
  month: number | null;
}

function clampPct(value: number | null): number | null {
  if (value === null) return null;
  if (Number.isNaN(value)) return null;
  if (value <= 0) return null;
  return Math.min(100, Math.round(value));
}

export default function DiscountsStep({ spotMarkers, defaultPrice, onChange }: DiscountsStepProps) {
  const t = useTranslations("host.discounts");

  const sharedTrio = useMemo<DiscountTrio>(() => {
    const first = spotMarkers[0];
    return {
      day: first?.discountDayPct ?? null,
      week: first?.discountWeekPct ?? null,
      month: first?.discountMonthPct ?? null,
    };
  }, [spotMarkers]);

  const updateTrio = (next: DiscountTrio) => {
    if (spotMarkers.length === 0) return;
    const updated = spotMarkers.map((s) => ({
      ...s,
      discountDayPct: next.day ?? undefined,
      discountWeekPct: next.week ?? undefined,
      discountMonthPct: next.month ?? undefined,
    }));
    onChange("spotMarkers", updated);
  };

  const setDay = (v: number | null) => updateTrio({ ...sharedTrio, day: clampPct(v) });
  const setWeek = (v: number | null) => updateTrio({ ...sharedTrio, week: clampPct(v) });
  const setMonth = (v: number | null) => updateTrio({ ...sharedTrio, month: clampPct(v) });

  const hourlyRate = useMemo(() => {
    const first = spotMarkers[0];
    return first?.pricePerHour ?? first?.price ?? defaultPrice ?? 0;
  }, [spotMarkers, defaultPrice]);

  if (spotMarkers.length === 0) {
    return (
      <div className="space-y-4">
        <div>
          <h2 className="text-2xl font-bold text-neutral-900">{t("title")}</h2>
          <p className="mt-2 text-sm text-neutral-500">{t("subtitle")}</p>
        </div>
        <div className="rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-900">
          {t("noSpotsYet")}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-neutral-900">{t("title")}</h2>
        <p className="mt-2 text-sm text-neutral-500">{t("subtitle")}</p>
      </div>

      <div className="rounded-2xl border border-neutral-200 bg-white p-5">
        <div className="space-y-1">
          <p className="text-base font-bold text-neutral-900">{t("cardTitle")}</p>
          <p className="text-xs text-neutral-500">{t("cardSubtitle")}</p>
        </div>

        <div className="mt-4 space-y-2">
          <DiscountRow
            label={t("dayLabel")}
            caption={t("dayCaption")}
            value={sharedTrio.day}
            onChange={setDay}
          />
          <DiscountRow
            label={t("weekLabel")}
            caption={t("weekCaption")}
            value={sharedTrio.week}
            onChange={setWeek}
          />
          <DiscountRow
            label={t("monthLabel")}
            caption={t("monthCaption")}
            value={sharedTrio.month}
            onChange={setMonth}
          />
        </div>

        <DiscountPreview trio={sharedTrio} hourlyRate={hourlyRate} />
      </div>

      <div className="flex items-start gap-2 rounded-2xl bg-primary-50 p-4 text-xs text-neutral-700">
        <Info className="mt-0.5 h-4 w-4 flex-none text-primary-600" />
        <p>{t("info")}</p>
      </div>
    </div>
  );
}

interface DiscountRowProps {
  label: string;
  caption: string;
  value: number | null;
  onChange: (value: number | null) => void;
}

function DiscountRow({ label, caption, value, onChange }: DiscountRowProps) {
  const [text, setText] = useState<string>(value !== null ? `${value}` : "");

  const commit = () => {
    const trimmed = text.trim();
    if (trimmed === "") {
      onChange(null);
      setText("");
      return;
    }
    const parsed = Number(trimmed);
    if (Number.isNaN(parsed) || parsed <= 0) {
      onChange(null);
      setText("");
      return;
    }
    const clamped = Math.min(100, Math.max(0, Math.round(parsed)));
    onChange(clamped > 0 ? clamped : null);
    setText(clamped > 0 ? `${clamped}` : "");
  };

  return (
    <div className="flex items-center gap-3 rounded-xl bg-neutral-50 px-3 py-2.5">
      <div className="flex-1">
        <p className="text-sm font-semibold text-neutral-900">{label}</p>
        <p className="text-xs text-neutral-500">{caption}</p>
      </div>
      <div className="flex items-center gap-1">
        <input
          type="number"
          inputMode="numeric"
          min={0}
          max={100}
          value={text}
          placeholder="0"
          onChange={(e) => setText(e.target.value)}
          onBlur={commit}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              (e.target as HTMLInputElement).blur();
            }
          }}
          className="w-14 rounded-lg border border-neutral-200 bg-white px-2 py-1.5 text-right text-base font-bold text-neutral-900 outline-none focus:border-primary-600 focus:ring-1 focus:ring-primary-600"
        />
        <span className="text-sm font-semibold text-neutral-500">%</span>
      </div>
    </div>
  );
}

interface DiscountPreviewProps {
  trio: DiscountTrio;
  hourlyRate: number;
}

function DiscountPreview({ trio, hourlyRate }: DiscountPreviewProps) {
  const t = useTranslations("host.discounts");
  const hasAny = (trio.day ?? 0) > 0 || (trio.week ?? 0) > 0 || (trio.month ?? 0) > 0;
  if (!hasAny || hourlyRate <= 0) return null;

  const fmt = (kr: number) => kr.toLocaleString("nb-NO");

  type Row = { label: string; hours: number; pct: number };
  const rows: Row[] = [];
  if ((trio.day ?? 0) > 0) rows.push({ label: t("dayLabel"), hours: 24, pct: trio.day! });
  if ((trio.week ?? 0) > 0) rows.push({ label: t("weekLabel"), hours: 24 * 7, pct: trio.week! });
  if ((trio.month ?? 0) > 0) rows.push({ label: t("monthLabel"), hours: 24 * 30, pct: trio.month! });

  return (
    <div className="mt-4 rounded-xl bg-primary-50/60 p-3 text-xs">
      <div className="mb-2 flex items-center gap-1.5 font-semibold text-neutral-700">
        <Sparkles className="h-3.5 w-3.5 text-primary-600" />
        {t("previewTitle")}
      </div>
      <div className="space-y-2">
        {rows.map((row) => {
          const base = hourlyRate * row.hours;
          const after = Math.round(base * (1 - row.pct / 100));
          const saved = base - after;
          return (
            <div key={row.label} className="flex items-start justify-between gap-2">
              <span className="font-semibold text-neutral-800">{row.label}</span>
              <div className="flex flex-col items-end">
                <div className="flex items-center gap-2">
                  <span className="text-neutral-400 line-through">{fmt(base)} kr</span>
                  <span className="text-sm font-bold text-neutral-900">{fmt(after)} kr</span>
                </div>
                <span className="text-[11px] font-medium text-primary-700">
                  {t("savedAmount", { amount: fmt(saved) })}
                </span>
              </div>
            </div>
          );
        })}
      </div>
      <p className="mt-2 text-[11px] text-neutral-500">
        {t("previewFootnote", { rate: fmt(hourlyRate) })}
      </p>
    </div>
  );
}
