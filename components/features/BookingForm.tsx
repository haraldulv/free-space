"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { DateRange } from "react-day-picker";
import { differenceInDays, format } from "date-fns";
import { CalendarDays, Star, Users, Plus, Minus } from "lucide-react";
import DatePicker from "@/components/ui/DatePicker";
import Button from "@/components/ui/Button";
import { Listing } from "@/types";
import { SERVICE_FEE_RATE } from "@/lib/config";
import { checkAvailabilityAction } from "@/app/(main)/book/actions";

interface BookingFormProps {
  listing: Listing;
}

export default function BookingForm({ listing }: BookingFormProps) {
  const router = useRouter();
  const [dateRange, setDateRange] = useState<DateRange | undefined>();
  const [showCalendar, setShowCalendar] = useState(false);
  const [availability, setAvailability] = useState<{ availableSpots: number; totalSpots: number } | null>(null);
  const [checkingAvailability, setCheckingAvailability] = useState(false);
  const [selectedExtras, setSelectedExtras] = useState<Record<string, number>>({});

  const nights =
    dateRange?.from && dateRange?.to
      ? differenceInDays(dateRange.to, dateRange.from)
      : 0;

  useEffect(() => {
    if (!dateRange?.from || !dateRange?.to || nights < 1) {
      setAvailability(null);
      return;
    }
    setCheckingAvailability(true);
    checkAvailabilityAction({
      listingId: listing.id,
      checkIn: format(dateRange.from, "yyyy-MM-dd"),
      checkOut: format(dateRange.to, "yyyy-MM-dd"),
    }).then((result) => {
      setAvailability(result);
      setCheckingAvailability(false);
    });
  }, [dateRange?.from?.getTime(), dateRange?.to?.getTime(), listing.id, nights]);

  const subtotal = listing.price * (nights || 1);

  const extrasTotal = (listing.extras || []).reduce((sum, extra) => {
    const qty = selectedExtras[extra.id] || 0;
    if (qty === 0) return sum;
    return sum + extra.price * (extra.perNight ? (nights || 1) : 1) * qty;
  }, 0);

  const serviceFee = Math.round((subtotal + extrasTotal) * SERVICE_FEE_RATE);
  const total = subtotal + extrasTotal + serviceFee;

  const disabledDates = (listing.blockedDates || []).map((d) => new Date(d + "T00:00:00"));

  const toggleExtra = (extraId: string, delta: number) => {
    setSelectedExtras((prev) => {
      const current = prev[extraId] || 0;
      const next = Math.max(0, current + delta);
      if (next === 0) {
        const { [extraId]: _, ...rest } = prev;
        return rest;
      }
      return { ...prev, [extraId]: next };
    });
  };

  const handleBook = () => {
    if (!dateRange?.from || !dateRange?.to) {
      setShowCalendar(true);
      return;
    }
    if (differenceInDays(dateRange.to, dateRange.from) < 1) return;

    const params = new URLSearchParams({
      checkIn: dateRange.from.toISOString(),
      checkOut: dateRange.to.toISOString(),
    });
    const extrasForUrl = Object.entries(selectedExtras)
      .filter(([, qty]) => qty > 0)
      .map(([id, qty]) => `${id}:${qty}`)
      .join(",");
    if (extrasForUrl) params.set("extras", extrasForUrl);

    router.push(`/book/${listing.id}?${params.toString()}`);
  };

  const priceLabel = listing.priceUnit === "time" ? "dag" : "natt";
  const hasExtras = (listing.extras || []).length > 0;

  return (
    <div className="lg:sticky lg:top-24 rounded-xl border border-neutral-200 bg-white p-4 sm:p-6 shadow-sm">
      <div className="flex items-baseline justify-between">
        <div>
          <span className="text-2xl font-bold text-neutral-900">
            {listing.price} kr
          </span>
          <span className="text-neutral-500"> /{priceLabel}</span>
        </div>
        <div className="flex items-center gap-1 text-sm">
          <Star className="h-4 w-4 fill-amber-400 text-amber-400" />
          <span className="font-medium">{listing.rating}</span>
          <span className="text-neutral-400">({listing.reviewCount})</span>
        </div>
      </div>

      <div className="mt-6">
        <button
          onClick={() => setShowCalendar(!showCalendar)}
          className="flex w-full items-center gap-2 rounded-lg border border-neutral-300 px-4 py-3 text-left text-sm transition-colors hover:border-neutral-400"
        >
          <CalendarDays className="h-4 w-4 text-neutral-400" />
          {dateRange?.from && dateRange?.to ? (
            <span className="text-neutral-900">
              {dateRange.from.toLocaleDateString("nb-NO")} –{" "}
              {dateRange.to.toLocaleDateString("nb-NO")}
            </span>
          ) : (
            <span className="text-neutral-400">Velg datoer</span>
          )}
        </button>
        {showCalendar && (
          <div className="mt-2">
            <DatePicker selected={dateRange} onSelect={setDateRange} disabled={disabledDates} />
          </div>
        )}
      </div>

      {nights > 0 && availability && (
        <div className="mt-4 flex items-center gap-2 rounded-lg bg-neutral-50 px-3 py-2 text-sm">
          <Users className="h-4 w-4 text-neutral-400" />
          <span className={availability.availableSpots === 0 ? "font-medium text-red-600" : "text-neutral-600"}>
            {availability.availableSpots}/{availability.totalSpots} plasser tilgjengelig
          </span>
        </div>
      )}

      {/* Extras selection */}
      {hasExtras && nights > 0 && (
        <div className="mt-4 border-t border-neutral-100 pt-4">
          <p className="text-sm font-medium text-neutral-700 mb-3">Tilleggstjenester</p>
          <div className="space-y-2">
            {(listing.extras || []).map((extra) => {
              const qty = selectedExtras[extra.id] || 0;
              const extraCost = extra.price * (extra.perNight ? nights : 1);
              return (
                <div key={extra.id} className="flex items-center justify-between text-sm">
                  <div>
                    <span className="text-neutral-700">{extra.name}</span>
                    <span className="ml-1 text-neutral-400">
                      {extra.price} kr{extra.perNight ? "/natt" : ""}
                    </span>
                  </div>
                  <div className="flex items-center gap-2">
                    {qty > 0 && <span className="text-xs text-neutral-500">{extraCost * qty} kr</span>}
                    <button
                      onClick={() => toggleExtra(extra.id, -1)}
                      disabled={qty === 0}
                      className="flex h-7 w-7 items-center justify-center rounded-full border border-neutral-200 text-neutral-500 disabled:opacity-30 hover:bg-neutral-50"
                    >
                      <Minus className="h-3 w-3" />
                    </button>
                    <span className="w-4 text-center text-sm font-medium">{qty}</span>
                    <button
                      onClick={() => toggleExtra(extra.id, 1)}
                      className="flex h-7 w-7 items-center justify-center rounded-full border border-neutral-200 text-neutral-500 hover:bg-neutral-50"
                    >
                      <Plus className="h-3 w-3" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {nights > 0 && (
        <div className="mt-4 space-y-2 border-t border-neutral-100 pt-4 text-sm">
          <div className="flex justify-between text-neutral-600">
            <span>
              {listing.price} kr &times; {nights} {nights === 1 ? priceLabel : priceLabel === "dag" ? "dager" : "netter"}
            </span>
            <span>{subtotal} kr</span>
          </div>
          {extrasTotal > 0 && (
            <div className="flex justify-between text-neutral-600">
              <span>Tilleggstjenester</span>
              <span>{extrasTotal} kr</span>
            </div>
          )}
          <div className="flex justify-between text-neutral-600">
            <span>Serviceavgift</span>
            <span>{serviceFee} kr</span>
          </div>
          <div className="flex justify-between border-t border-neutral-100 pt-2 font-semibold text-neutral-900">
            <span>Totalt</span>
            <span>{total} kr</span>
          </div>
        </div>
      )}

      <Button
        onClick={handleBook}
        size="lg"
        className="mt-6 w-full"
        disabled={checkingAvailability || (availability !== null && availability.availableSpots === 0)}
      >
        {checkingAvailability
          ? "Sjekker tilgjengelighet..."
          : availability?.availableSpots === 0
            ? "Fullbooket"
            : dateRange?.from && dateRange?.to
              ? "Reserver"
              : "Sjekk tilgjengelighet"}
      </Button>
    </div>
  );
}
