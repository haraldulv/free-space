"use client";

import { useMemo, useState } from "react";
import { Sparkles, Info } from "lucide-react";
import { useTranslations } from "next-intl";
import type { SpotMarker } from "@/types";

interface LongerStayStepProps {
  spotMarkers: SpotMarker[];
  defaultPrice: number;
  priceUnit: "time" | "natt" | "hour";
  onChange: (field: string, value: unknown) => void;
}

interface LongerStayPrices {
  daily: number | null;
  weekly: number | null;
  monthly: number | null;
}

function clamp(value: number | null): number | null {
  if (value === null) return null;
  if (Number.isNaN(value) || value <= 0) return null;
  return Math.round(value);
}

/**
 * "Lengre opphold"-steg.
 *
 * Lar verten sette en fast pris (kr) for et fullt døgn, en uke og en måned.
 * Erstatter %-rabatter — gir en mye renere mental modell for både parkering
 * og camping. La feltene stå tomme for å skippe en tier.
 *
 * Default-modus: Felles for alle plasser. Skriver til alle spotMarkers ved
 * endring (90% av hosts har 1 plass uansett).
 *
 * For camping (priceUnit=natt) er døgn-pris allerede "natt"-prisen, så
 * "1 døgn"-input gjemmes — kun uke + måned vises.
 */
export default function DiscountsStep({
  spotMarkers,
  defaultPrice,
  priceUnit,
  onChange,
}: LongerStayStepProps) {
  const t = useTranslations("host.longerStay");
  const isCamping = priceUnit === "natt";

  const sharedPrices = useMemo<LongerStayPrices>(() => {
    const first = spotMarkers[0];
    return {
      daily: first?.dailyPrice ?? null,
      weekly: first?.weeklyPrice ?? null,
      monthly: first?.monthlyPrice ?? null,
    };
  }, [spotMarkers]);

  const updatePrices = (next: LongerStayPrices) => {
    if (spotMarkers.length === 0) return;
    const updated = spotMarkers.map((s) => ({
      ...s,
      dailyPrice: next.daily ?? undefined,
      weeklyPrice: next.weekly ?? undefined,
      monthlyPrice: next.monthly ?? undefined,
      // Fjern legacy %-felter når host setter kr-priser, så det ikke ligger
      // dobbel-konfigurasjon i DB.
      discountDayPct: undefined,
      discountWeekPct: undefined,
      discountMonthPct: undefined,
    }));
    onChange("spotMarkers", updated);
  };

  const setDaily = (v: number | null) =>
    updatePrices({ ...sharedPrices, daily: clamp(v) });
  const setWeekly = (v: number | null) =>
    updatePrices({ ...sharedPrices, weekly: clamp(v) });
  const setMonthly = (v: number | null) =>
    updatePrices({ ...sharedPrices, monthly: clamp(v) });

  // Basisreferanse for hint-tekstene (full pris uten lengre-opphold-tilbud).
  const basePrice = useMemo(() => {
    const first = spotMarkers[0];
    if (isCamping) return first?.pricePerNight ?? first?.price ?? defaultPrice ?? 0;
    return first?.pricePerHour ?? first?.price ?? defaultPrice ?? 0;
  }, [spotMarkers, defaultPrice, isCamping]);

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

  const dailyBaseline = isCamping ? basePrice : basePrice * 24;
  const weeklyBaseline = isCamping ? basePrice * 7 : basePrice * 24 * 7;
  const monthlyBaseline = isCamping ? basePrice * 30 : basePrice * 24 * 30;

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
          {!isCamping && (
            <PriceRow
              label={t("dailyLabel")}
              caption={t("dailyCaption")}
              baselineHint={t("baselineHint", { amount: fmt(dailyBaseline) })}
              value={sharedPrices.daily}
              onChange={setDaily}
            />
          )}
          <PriceRow
            label={t("weeklyLabel")}
            caption={t("weeklyCaption")}
            baselineHint={t("baselineHint", { amount: fmt(weeklyBaseline) })}
            value={sharedPrices.weekly}
            onChange={setWeekly}
          />
          <PriceRow
            label={t("monthlyLabel")}
            caption={t("monthlyCaption")}
            baselineHint={t("baselineHint", { amount: fmt(monthlyBaseline) })}
            value={sharedPrices.monthly}
            onChange={setMonthly}
          />
        </div>

        <SavingsPreview
          prices={sharedPrices}
          dailyBaseline={dailyBaseline}
          weeklyBaseline={weeklyBaseline}
          monthlyBaseline={monthlyBaseline}
          isCamping={isCamping}
        />
      </div>

      <div className="flex items-start gap-2 rounded-2xl bg-primary-50 p-4 text-xs text-neutral-700">
        <Info className="mt-0.5 h-4 w-4 flex-none text-primary-600" />
        <p>{t("info")}</p>
      </div>
    </div>
  );
}

function fmt(kr: number): string {
  return Math.round(kr).toLocaleString("nb-NO");
}

interface PriceRowProps {
  label: string;
  caption: string;
  baselineHint: string;
  value: number | null;
  onChange: (value: number | null) => void;
}

function PriceRow({ label, caption, baselineHint, value, onChange }: PriceRowProps) {
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
    const rounded = Math.max(0, Math.round(parsed));
    onChange(rounded > 0 ? rounded : null);
    setText(rounded > 0 ? `${rounded}` : "");
  };

  return (
    <div className="rounded-xl bg-neutral-50 px-3 py-2.5">
      <div className="flex items-center gap-3">
        <div className="flex-1">
          <p className="text-sm font-semibold text-neutral-900">{label}</p>
          <p className="text-xs text-neutral-500">{caption}</p>
        </div>
        <div className="flex items-center gap-1.5">
          <input
            type="number"
            inputMode="numeric"
            min={0}
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
            className="w-24 rounded-lg border border-neutral-200 bg-white px-2 py-1.5 text-right text-base font-bold text-neutral-900 outline-none focus:border-primary-600 focus:ring-1 focus:ring-primary-600"
          />
          <span className="text-sm font-semibold text-neutral-500">kr</span>
        </div>
      </div>
      <p className="mt-1.5 text-[11px] text-neutral-400">{baselineHint}</p>
    </div>
  );
}

interface SavingsPreviewProps {
  prices: LongerStayPrices;
  dailyBaseline: number;
  weeklyBaseline: number;
  monthlyBaseline: number;
  isCamping: boolean;
}

function SavingsPreview({
  prices,
  dailyBaseline,
  weeklyBaseline,
  monthlyBaseline,
  isCamping,
}: SavingsPreviewProps) {
  const t = useTranslations("host.longerStay");
  type Row = { label: string; tierPrice: number; baseline: number };
  const rows: Row[] = [];
  if (!isCamping && prices.daily && prices.daily > 0) {
    rows.push({ label: t("dailyLabel"), tierPrice: prices.daily, baseline: dailyBaseline });
  }
  if (prices.weekly && prices.weekly > 0) {
    rows.push({ label: t("weeklyLabel"), tierPrice: prices.weekly, baseline: weeklyBaseline });
  }
  if (prices.monthly && prices.monthly > 0) {
    rows.push({ label: t("monthlyLabel"), tierPrice: prices.monthly, baseline: monthlyBaseline });
  }
  if (rows.length === 0) return null;

  return (
    <div className="mt-4 rounded-xl bg-primary-50/60 p-3 text-xs">
      <div className="mb-2 flex items-center gap-1.5 font-semibold text-neutral-700">
        <Sparkles className="h-3.5 w-3.5 text-primary-600" />
        {t("previewTitle")}
      </div>
      <div className="space-y-2">
        {rows.map((row) => {
          const saved = Math.max(0, row.baseline - row.tierPrice);
          return (
            <div key={row.label} className="flex items-start justify-between gap-2">
              <span className="font-semibold text-neutral-800">{row.label}</span>
              <div className="flex flex-col items-end">
                <div className="flex items-center gap-2">
                  <span className="text-neutral-400 line-through">{fmt(row.baseline)} kr</span>
                  <span className="text-sm font-bold text-neutral-900">{fmt(row.tierPrice)} kr</span>
                </div>
                {saved > 0 && (
                  <span className="text-[11px] font-medium text-primary-700">
                    {t("savedAmount", { amount: fmt(saved) })}
                  </span>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
