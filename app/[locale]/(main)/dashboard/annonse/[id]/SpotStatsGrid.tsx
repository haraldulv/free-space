"use client";

import { CalendarCheck, TrendingUp } from "lucide-react";
import { useTranslations } from "next-intl";
import { Link } from "@/i18n/navigation";
import type { SpotStats } from "@/lib/supabase/stats";

export function SpotStatsGrid({ listingId, stats }: { listingId: string; stats: SpotStats[] }) {
  const t = useTranslations("hostStats");

  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
      {stats.map((s) => (
        <Link
          key={s.spotId}
          href={`/dashboard/annonse/${listingId}/plass/${s.spotId}`}
          className="group rounded-xl border border-neutral-200 bg-white p-4 transition-shadow hover:shadow-sm"
        >
          <div className="flex items-baseline justify-between">
            <h3 className="text-sm font-semibold text-neutral-900 group-hover:text-primary-700">
              {s.label}
            </h3>
            <span className="text-xs text-neutral-400">→</span>
          </div>
          <div className="mt-3 grid grid-cols-2 gap-3 text-sm">
            <div>
              <div className="flex items-center gap-1 text-xs text-neutral-500">
                <TrendingUp className="h-3 w-3" />
                {t("occupancy30Short")}
              </div>
              <div className="mt-0.5 font-medium text-neutral-900">{s.occupancyPct}%</div>
            </div>
            <div>
              <div className="flex items-center gap-1 text-xs text-neutral-500">
                <CalendarCheck className="h-3 w-3" />
                {t("upcomingShort")}
              </div>
              <div className="mt-0.5 font-medium text-neutral-900">{s.upcomingBookings}</div>
            </div>
            <div className="col-span-2">
              <div className="text-xs text-neutral-500">{t("revenue30Short")}</div>
              <div className="mt-0.5 font-medium text-neutral-900">
                {s.revenue.toLocaleString("nb-NO")} kr
              </div>
            </div>
            {s.nextCheckIn && (
              <div className="col-span-2 text-xs text-neutral-500">
                {t("nextShort", { date: s.nextCheckIn })}
              </div>
            )}
          </div>
        </Link>
      ))}
    </div>
  );
}
