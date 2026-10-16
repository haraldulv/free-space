"use client";

import { useMemo, useState } from "react";
import { useTranslations } from "next-intl";

const nok = new Intl.NumberFormat("nb-NO");

/** Tuno-grønn (brand, samme som /tjen-heroen og app-ikonet). */
const GREEN = "#46C185";

/**
 * Pendli-inspirert kalkulator (Kim-feedback): to slidere i stedet for
 * dropdown-skjema. Brukeren styrer dagspris og antall utleide dager selv,
 * og ser estimatet oppdatere seg umiddelbart.
 */
export default function EarnCalculator() {
  const t = useTranslations("tjen");
  const [dayPrice, setDayPrice] = useState(70);
  const [daysPerMonth, setDaysPerMonth] = useState(20);

  const monthly = useMemo(() => dayPrice * daysPerMonth, [dayPrice, daysPerMonth]);
  const yearly = monthly * 12;

  const presets: { label: string; days: number }[] = [
    { label: t("presetWeekdays"), days: 20 },
    { label: t("presetWeekends"), days: 8 },
    { label: t("presetAll"), days: 30 },
  ];

  return (
    <div className="rounded-3xl bg-[#fdfcf9] p-6 shadow-[0_18px_50px_rgba(18,20,18,0.18)] sm:p-8">
      <h2 className="text-xl font-bold text-neutral-900 sm:text-2xl">{t("calcTitle")}</h2>

      <div className="mt-6 space-y-7">
        <div>
          <div className="mb-1 flex items-baseline justify-between">
            <label htmlFor="earn-price" className="text-sm font-semibold text-neutral-700">
              {t("calcDayPriceLabel")}
            </label>
            <span className="text-lg font-bold text-neutral-900">{nok.format(dayPrice)} kr</span>
          </div>
          <input
            id="earn-price"
            type="range"
            min={20}
            max={300}
            step={5}
            value={dayPrice}
            onChange={(e) => setDayPrice(Number(e.target.value))}
            className="w-full"
            style={{ accentColor: GREEN }}
          />
          <div className="flex justify-between text-xs text-neutral-400">
            <span>20 kr</span>
            <span>300 kr</span>
          </div>
        </div>

        <div>
          <div className="mb-1 flex items-baseline justify-between">
            <label htmlFor="earn-days" className="text-sm font-semibold text-neutral-700">
              {t("calcDaysLabel")}
            </label>
            <span className="text-lg font-bold text-neutral-900">{daysPerMonth}</span>
          </div>
          <input
            id="earn-days"
            type="range"
            min={1}
            max={30}
            step={1}
            value={daysPerMonth}
            onChange={(e) => setDaysPerMonth(Number(e.target.value))}
            className="w-full"
            style={{ accentColor: GREEN }}
          />
          <div className="flex justify-between text-xs text-neutral-400">
            <span>1</span>
            <span>30</span>
          </div>
          <div className="mt-3 flex flex-wrap gap-2">
            {presets.map((preset) => {
              const active = preset.days === daysPerMonth;
              return (
                <button
                  key={preset.label}
                  type="button"
                  onClick={() => setDaysPerMonth(preset.days)}
                  className={`rounded-full px-4 py-2 text-sm font-semibold transition-colors ${
                    active
                      ? "bg-neutral-900 text-white"
                      : "bg-neutral-100 text-neutral-700 hover:bg-neutral-200"
                  }`}
                >
                  {preset.label}
                </button>
              );
            })}
          </div>
        </div>
      </div>

      <div className="mt-7 rounded-2xl px-6 py-5 text-white" style={{ background: GREEN }}>
        <p className="text-xs font-bold uppercase tracking-wide text-white/80">
          {t("estimateTitle")}
        </p>
        <p className="mt-1 text-4xl font-bold">
          {nok.format(monthly)} kr
        </p>
        <p className="mt-2 text-sm font-medium text-white/90">
          {t("calcFormula", { price: nok.format(dayPrice), days: daysPerMonth })} ·{" "}
          {t("estimateYear", { amount: nok.format(yearly) })}
        </p>
      </div>

      <p className="mt-4 text-xs leading-relaxed text-neutral-500">{t("estimateNote")}</p>
    </div>
  );
}
