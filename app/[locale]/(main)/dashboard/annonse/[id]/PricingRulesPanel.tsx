"use client";

import { useState, useTransition } from "react";
import { CalendarRange, Plus, Trash2, Check } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import { bcpLocale } from "@/lib/i18n-helpers";
import Button from "@/components/ui/Button";
import Toggle from "@/components/ui/Toggle";
import {
  setWeekendPriceAction,
  addSeasonRuleAction,
  removeRuleAction,
} from "./actions";

interface SeasonRule {
  id: string;
  startDate: string;
  endDate: string;
  price: number;
}

interface Props {
  listingId: string;
  basePrice: number;
  initialWeekendPrice: number | null;
  initialSeasonRules: SeasonRule[];
}

export function PricingRulesPanel({
  listingId,
  basePrice,
  initialWeekendPrice,
  initialSeasonRules,
}: Props) {
  const t = useTranslations("hostPricing");
  const locale = useLocale();
  const dfLocale = bcpLocale(locale);
  const [pending, startTransition] = useTransition();

  const [weekendEnabled, setWeekendEnabled] = useState(initialWeekendPrice != null);
  const [weekendPrice, setWeekendPrice] = useState<string>(
    initialWeekendPrice != null ? String(initialWeekendPrice) : String(Math.round(basePrice * 1.25)),
  );
  const [weekendDirty, setWeekendDirty] = useState(false);
  const [weekendSaved, setWeekendSaved] = useState(false);

  const [seasonRules, setSeasonRules] = useState<SeasonRule[]>(initialSeasonRules);
  const [newSeason, setNewSeason] = useState<{ start: string; end: string; price: string }>({
    start: "",
    end: "",
    price: String(Math.round(basePrice * 1.5)),
  });
  const [error, setError] = useState<string | null>(null);

  const handleWeekendSave = () => {
    setError(null);
    const price = weekendEnabled ? Number(weekendPrice) : null;
    if (weekendEnabled && (!price || price <= 0)) {
      setError(t("invalidPrice"));
      return;
    }
    startTransition(async () => {
      const res = await setWeekendPriceAction(listingId, price);
      if (res.error) setError(res.error);
      else {
        setWeekendDirty(false);
        setWeekendSaved(true);
        setTimeout(() => setWeekendSaved(false), 2000);
      }
    });
  };

  const handleAddSeason = () => {
    setError(null);
    const price = Number(newSeason.price);
    if (!newSeason.start || !newSeason.end) {
      setError(t("missingDates"));
      return;
    }
    if (!price || price <= 0) {
      setError(t("invalidPrice"));
      return;
    }
    startTransition(async () => {
      const res = await addSeasonRuleAction(listingId, newSeason.start, newSeason.end, price);
      if (res.error) {
        setError(res.error);
        return;
      }
      setSeasonRules([
        ...seasonRules,
        {
          id: crypto.randomUUID(),  // optimistic; revalidatePath henter fresh
          startDate: newSeason.start,
          endDate: newSeason.end,
          price,
        },
      ]);
      setNewSeason({ start: "", end: "", price: String(Math.round(basePrice * 1.5)) });
    });
  };

  const handleRemoveRule = (ruleId: string) => {
    setError(null);
    startTransition(async () => {
      const res = await removeRuleAction(listingId, ruleId);
      if (res.error) {
        setError(res.error);
        return;
      }
      setSeasonRules(seasonRules.filter((r) => r.id !== ruleId));
    });
  };

  const formatRange = (start: string, end: string) => {
    const s = new Date(start + "T00:00:00");
    const e = new Date(end + "T00:00:00");
    const sameYear = s.getFullYear() === e.getFullYear();
    const fmt: Intl.DateTimeFormatOptions = { day: "numeric", month: "short", ...(sameYear ? {} : { year: "numeric" }) };
    return `${s.toLocaleDateString(dfLocale, fmt)} – ${e.toLocaleDateString(dfLocale, { ...fmt, year: "numeric" })}`;
  };

  return (
    <div className="mt-10">
      <h2 className="text-lg font-semibold text-neutral-900">{t("title")}</h2>
      <p className="mt-1 text-sm text-neutral-500">
        {t("description", { basePrice })}
      </p>

      {/* Helg-pris */}
      <div className="mt-5 rounded-xl border border-neutral-200 bg-white p-5">
        <div className="flex items-start justify-between gap-4">
          <div className="flex-1">
            <h3 className="text-base font-semibold text-neutral-900">{t("weekendTitle")}</h3>
            <p className="mt-1 text-sm text-neutral-500">{t("weekendDescription")}</p>
          </div>
          <Toggle
            checked={weekendEnabled}
            onChange={(v) => { setWeekendEnabled(v); setWeekendDirty(true); setWeekendSaved(false); }}
            label=""
          />
        </div>

        {weekendEnabled && (
          <div className="mt-4 flex items-end gap-3">
            <div>
              <label className="block text-sm font-medium text-neutral-700 mb-1.5">{t("priceLabel")}</label>
              <div className="flex items-center gap-2">
                <input
                  type="number"
                  value={weekendPrice}
                  onChange={(e) => { setWeekendPrice(e.target.value); setWeekendDirty(true); setWeekendSaved(false); }}
                  className="w-32 rounded-lg border border-neutral-300 px-3 py-2 text-sm"
                  placeholder="F.eks. 400"
                />
                <span className="text-sm text-neutral-500">kr/natt</span>
              </div>
            </div>
          </div>
        )}

        <div className="mt-4 flex items-center gap-3">
          <Button
            size="sm"
            onClick={handleWeekendSave}
            disabled={pending || (!weekendDirty && !weekendSaved)}
          >
            {weekendSaved ? (
              <span className="inline-flex items-center gap-1">
                <Check className="h-3.5 w-3.5" />
                {t("saved")}
              </span>
            ) : pending ? t("saving") : t("save")}
          </Button>
        </div>
      </div>

      {/* Sesong-regler */}
      <div className="mt-5 rounded-xl border border-neutral-200 bg-white p-5">
        <div className="flex items-start justify-between gap-4">
          <div>
            <h3 className="text-base font-semibold text-neutral-900">{t("seasonTitle")}</h3>
            <p className="mt-1 text-sm text-neutral-500">{t("seasonDescription")}</p>
          </div>
        </div>

        {seasonRules.length > 0 && (
          <div className="mt-4 space-y-2">
            {seasonRules.map((rule) => (
              <div
                key={rule.id}
                className="flex items-center justify-between gap-3 rounded-lg border border-neutral-200 px-3 py-2.5"
              >
                <div className="flex items-center gap-2.5 text-sm">
                  <CalendarRange className="h-4 w-4 text-neutral-400" />
                  <span className="text-neutral-700">{formatRange(rule.startDate, rule.endDate)}</span>
                  <span className="text-neutral-400">·</span>
                  <span className="font-medium text-neutral-900">{rule.price} kr/natt</span>
                </div>
                <button
                  type="button"
                  onClick={() => handleRemoveRule(rule.id)}
                  disabled={pending}
                  className="text-neutral-400 hover:text-red-500 disabled:opacity-50"
                  aria-label={t("removeSeason")}
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              </div>
            ))}
          </div>
        )}

        {/* Add new */}
        <div className="mt-4 grid grid-cols-1 gap-3 sm:grid-cols-[1fr_1fr_100px_auto]">
          <div>
            <label className="block text-xs font-medium text-neutral-600 mb-1">{t("startDate")}</label>
            <input
              type="date"
              value={newSeason.start}
              onChange={(e) => setNewSeason({ ...newSeason, start: e.target.value })}
              className="w-full rounded-lg border border-neutral-300 px-3 py-2 text-sm"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-neutral-600 mb-1">{t("endDate")}</label>
            <input
              type="date"
              value={newSeason.end}
              onChange={(e) => setNewSeason({ ...newSeason, end: e.target.value })}
              className="w-full rounded-lg border border-neutral-300 px-3 py-2 text-sm"
            />
          </div>
          <div>
            <label className="block text-xs font-medium text-neutral-600 mb-1">{t("priceLabel")}</label>
            <input
              type="number"
              value={newSeason.price}
              onChange={(e) => setNewSeason({ ...newSeason, price: e.target.value })}
              className="w-full rounded-lg border border-neutral-300 px-3 py-2 text-sm"
            />
          </div>
          <Button
            size="sm"
            onClick={handleAddSeason}
            disabled={pending}
            className="self-end"
          >
            <Plus className="h-3.5 w-3.5 mr-1" />
            {t("addSeason")}
          </Button>
        </div>
      </div>

      {error && <p className="mt-3 text-sm text-red-600">{error}</p>}
    </div>
  );
}
