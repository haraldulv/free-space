"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { DateRange } from "react-day-picker";
import { differenceInDays } from "date-fns";
import { CalendarDays, Star } from "lucide-react";
import DatePicker from "@/components/ui/DatePicker";
import Button from "@/components/ui/Button";
import { Listing } from "@/types";

interface BookingFormProps {
  listing: Listing;
}

export default function BookingForm({ listing }: BookingFormProps) {
  const router = useRouter();
  const [dateRange, setDateRange] = useState<DateRange | undefined>();
  const [showCalendar, setShowCalendar] = useState(false);

  const nights =
    dateRange?.from && dateRange?.to
      ? differenceInDays(dateRange.to, dateRange.from)
      : 0;

  const subtotal = listing.price * (nights || 1);
  const serviceFee = Math.round(subtotal * 0.1);
  const total = subtotal + serviceFee;

  const handleBook = () => {
    if (!dateRange?.from || !dateRange?.to) {
      setShowCalendar(true);
      return;
    }
    const params = new URLSearchParams({
      checkIn: dateRange.from.toISOString(),
      checkOut: dateRange.to.toISOString(),
    });
    router.push(`/book/${listing.id}?${params.toString()}`);
  };

  const priceLabel = listing.priceUnit === "time" ? "dag" : "natt";

  return (
    <div className="sticky top-24 rounded-xl border border-neutral-200 bg-white p-6 shadow-sm">
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
            <DatePicker selected={dateRange} onSelect={setDateRange} />
          </div>
        )}
      </div>

      {nights > 0 && (
        <div className="mt-4 space-y-2 border-t border-neutral-100 pt-4 text-sm">
          <div className="flex justify-between text-neutral-600">
            <span>
              {listing.price} kr &times; {nights} {nights === 1 ? priceLabel : priceLabel === "dag" ? "dager" : "netter"}
            </span>
            <span>{subtotal} kr</span>
          </div>
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

      <Button onClick={handleBook} size="lg" className="mt-6 w-full">
        {dateRange?.from && dateRange?.to ? "Reserver" : "Sjekk tilgjengelighet"}
      </Button>
    </div>
  );
}
