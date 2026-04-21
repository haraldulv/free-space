"use client";

import Image from "next/image";
import { CalendarDays, MapPin, Clock } from "lucide-react";
import { useLocale, useTranslations } from "next-intl";
import Badge from "@/components/ui/Badge";
import { Listing, SelectedExtras } from "@/types";
import { bcpLocale } from "@/lib/i18n-helpers";

interface BookingSummaryProps {
  listing: Listing;
  checkIn: Date;
  checkOut: Date;
  nights: number;
  baseAmount?: number;
  selectedExtras?: SelectedExtras;
  selectedSpotCount?: number;
  subtotal: number;
  serviceFee: number;
  total: number;
  checkInTime?: string;
  checkOutTime?: string;
}

export default function BookingSummary({
  listing,
  checkIn,
  checkOut,
  nights,
  baseAmount,
  selectedExtras,
  selectedSpotCount,
  subtotal,
  serviceFee,
  total,
  checkInTime,
  checkOutTime,
}: BookingSummaryProps) {
  const t = useTranslations("booking");
  const tCategory = useTranslations("category");
  const locale = useLocale();
  const dateLocale = bcpLocale(locale);

  const resolvedBase = baseAmount ?? listing.price * nights;
  const spotCount = selectedSpotCount ?? 1;
  const isHourly = listing.priceUnit === "time";

  const baseLabel = spotCount > 1
    ? t("spotsTimesNights", { spots: spotCount, nights })
    : isHourly
      ? t("pricePerDayCalc", { price: listing.price, days: nights })
      : t("pricePerNightCalc", { price: listing.price, nights });

  const listingExtras = selectedExtras?.listing ?? [];
  const allSpotExtras = Object.values(selectedExtras?.spots ?? {}).flat();
  const hasExtras = listingExtras.length > 0 || allSpotExtras.length > 0;

  const renderExtraRow = (
    extra: { id: string; name: string; price: number; perNight: boolean; quantity: number },
    key: string,
  ) => {
    const amount = extra.price * (extra.perNight ? nights : 1) * extra.quantity;
    const qtyPart = extra.quantity > 1 ? ` × ${extra.quantity}` : "";
    const nightPart = extra.perNight ? ` × ${nights} ${nights === 1 ? "n" : "n"}` : "";
    return (
      <div key={key} className="flex justify-between text-neutral-600">
        <span>
          {extra.name}
          <span className="text-neutral-400">{qtyPart}{nightPart}</span>
        </span>
        <span>{amount} kr</span>
      </div>
    );
  };

  return (
    <div className="rounded-xl border border-neutral-200 bg-white p-6">
      <div className="flex gap-4">
        <div className="relative h-24 w-24 shrink-0 overflow-hidden rounded-lg">
          <Image
            src={listing.images[0]}
            alt={listing.title}
            fill
            className="object-cover"
            sizes="96px"
          />
        </div>
        <div>
          <Badge>
            {listing.category === "parking" ? tCategory("parking") : tCategory("camping")}
          </Badge>
          <h3 className="mt-1 font-semibold text-neutral-900">
            {listing.title}
          </h3>
          <div className="mt-1 flex items-center gap-1 text-sm text-neutral-500">
            <MapPin className="h-3.5 w-3.5" />
            {listing.location.city}, {listing.location.region}
          </div>
        </div>
      </div>

      <div className="mt-6 space-y-3 border-t border-neutral-100 pt-4">
        <div className="flex items-center gap-2 text-sm text-neutral-600">
          <CalendarDays className="h-4 w-4 text-neutral-400" />
          {checkIn.toLocaleDateString(dateLocale)} – {checkOut.toLocaleDateString(dateLocale)}
        </div>
        <div className="flex items-center gap-2 text-sm text-neutral-500">
          <Clock className="h-4 w-4 text-neutral-400" />
          {t("checkInFrom", { time: checkInTime || "15:00" })} / {t("checkOutBy", { time: checkOutTime || "11:00" })}
        </div>
      </div>

      <div className="mt-4 space-y-2 border-t border-neutral-100 pt-4 text-sm">
        <div className="flex justify-between text-neutral-600">
          <span>{baseLabel}</span>
          <span>{resolvedBase} kr</span>
        </div>

        {hasExtras && (
          <div className="border-t border-neutral-100 pt-2 space-y-1.5">
            <p className="text-xs font-semibold uppercase tracking-wide text-neutral-500">
              {t("extrasLabel")}
            </p>
            {listingExtras.map((extra) => renderExtraRow(extra, `l-${extra.id}`))}
            {allSpotExtras.map((extra, idx) => renderExtraRow(extra, `s-${idx}-${extra.id}`))}
          </div>
        )}

        {hasExtras && (
          <div className="flex justify-between border-t border-neutral-100 pt-2 text-neutral-600">
            <span>{t("subtotal")}</span>
            <span>{subtotal} kr</span>
          </div>
        )}

        <div className="flex justify-between text-neutral-600">
          <span>{t("serviceFeeLabel")}</span>
          <span>{serviceFee} kr</span>
        </div>

        <div className="flex justify-between border-t border-neutral-100 pt-2 text-base font-semibold text-neutral-900">
          <span>{t("totalLabel")}</span>
          <span>{total} kr</span>
        </div>
      </div>
    </div>
  );
}
