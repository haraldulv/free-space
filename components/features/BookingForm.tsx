"use client";

import { useState, useEffect, useMemo } from "react";
import { useRouter } from "next/navigation";
import { DateRange } from "react-day-picker";
import { differenceInDays, format } from "date-fns";
import { CalendarDays, Star, Users, Plus, Minus, MapPin, Sparkles } from "lucide-react";
import DatePicker from "@/components/ui/DatePicker";
import Button from "@/components/ui/Button";
import { Listing, SpotMarker, getDisplayPriceText } from "@/types";
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
  const [listingExtras, setListingExtras] = useState<Record<string, number>>({});
  const [spotExtras, setSpotExtras] = useState<Record<string, Record<string, number>>>({});
  const [selectedSpotIds, setSelectedSpotIds] = useState<string[]>([]);

  const spotMarkers = useMemo(() => listing.spotMarkers || [], [listing.spotMarkers]);
  const hasSpotLevelPricing = useMemo(
    () => spotMarkers.some((s) => s.price != null || (s.extras && s.extras.length > 0)),
    [spotMarkers],
  );

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

  const effectiveNights = nights || 1;

  // Datoer som er valgt av gjest (yyyy-MM-dd for hver natt i range)
  const selectedDateSet = useMemo(() => {
    const set = new Set<string>();
    if (!dateRange?.from || !dateRange?.to) return set;
    const cursor = new Date(dateRange.from);
    while (cursor < dateRange.to) {
      set.add(format(cursor, "yyyy-MM-dd"));
      cursor.setDate(cursor.getDate() + 1);
    }
    return set;
  }, [dateRange?.from?.getTime(), dateRange?.to?.getTime()]);

  const isSpotBlocked = (spot: SpotMarker): boolean => {
    if (!spot.blockedDates || spot.blockedDates.length === 0) return false;
    return spot.blockedDates.some((d) => selectedDateSet.has(d));
  };

  // Deselect spots that become blocked when date range changes
  useEffect(() => {
    if (selectedSpotIds.length === 0) return;
    const stillOk = selectedSpotIds.filter((id) => {
      const spot = spotMarkers.find((s) => s.id === id);
      return spot && !isSpotBlocked(spot);
    });
    if (stillOk.length !== selectedSpotIds.length) {
      setSelectedSpotIds(stillOk);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedDateSet]);

  const selectedSpots = useMemo<SpotMarker[]>(
    () => spotMarkers.filter((s) => s.id && selectedSpotIds.includes(s.id)),
    [spotMarkers, selectedSpotIds],
  );

  const baseTotal = useMemo(() => {
    if (hasSpotLevelPricing && selectedSpots.length > 0) {
      return selectedSpots.reduce(
        (sum, s) => sum + (s.price ?? listing.price) * effectiveNights,
        0,
      );
    }
    return listing.price * effectiveNights;
  }, [hasSpotLevelPricing, selectedSpots, listing.price, effectiveNights]);

  const listingExtrasTotal = useMemo(() => {
    return (listing.extras || []).reduce((sum, extra) => {
      const qty = listingExtras[extra.id] || 0;
      if (qty === 0) return sum;
      return sum + extra.price * (extra.perNight ? effectiveNights : 1) * qty;
    }, 0);
  }, [listing.extras, listingExtras, effectiveNights]);

  const spotExtrasTotal = useMemo(() => {
    return selectedSpots.reduce((sum, spot) => {
      const perSpot = (spot.extras || []).reduce((acc, extra) => {
        const qty = spotExtras[spot.id!]?.[extra.id] || 0;
        if (qty === 0) return acc;
        return acc + extra.price * (extra.perNight ? effectiveNights : 1) * qty;
      }, 0);
      return sum + perSpot;
    }, 0);
  }, [selectedSpots, spotExtras, effectiveNights]);

  const subtotal = baseTotal + listingExtrasTotal + spotExtrasTotal;
  const serviceFee = Math.round(subtotal * SERVICE_FEE_RATE);
  const total = subtotal + serviceFee;

  const disabledDates = (listing.blockedDates || []).map((d) => new Date(d + "T00:00:00"));

  const toggleListingExtra = (id: string, delta: number) => {
    setListingExtras((prev) => {
      const curr = prev[id] || 0;
      const next = Math.max(0, curr + delta);
      const copy = { ...prev };
      if (next === 0) delete copy[id];
      else copy[id] = next;
      return copy;
    });
  };

  const toggleSpotExtra = (spotId: string, extraId: string, delta: number) => {
    setSpotExtras((prev) => {
      const spot = { ...(prev[spotId] || {}) };
      const curr = spot[extraId] || 0;
      const next = Math.max(0, curr + delta);
      if (next === 0) delete spot[extraId];
      else spot[extraId] = next;
      const copy = { ...prev };
      if (Object.keys(spot).length === 0) delete copy[spotId];
      else copy[spotId] = spot;
      return copy;
    });
  };

  const toggleSpot = (spotId: string) => {
    setSelectedSpotIds((prev) =>
      prev.includes(spotId) ? prev.filter((id) => id !== spotId) : [...prev, spotId],
    );
  };

  const handleBook = () => {
    if (!dateRange?.from || !dateRange?.to) {
      setShowCalendar(true);
      return;
    }
    if (differenceInDays(dateRange.to, dateRange.from) < 1) return;
    if (hasSpotLevelPricing && selectedSpotIds.length === 0) return;

    const params = new URLSearchParams({
      checkIn: dateRange.from.toISOString(),
      checkOut: dateRange.to.toISOString(),
    });
    if (hasSpotLevelPricing && selectedSpotIds.length > 0) {
      params.set("spots", selectedSpotIds.join(","));
    }
    const payload = { listing: listingExtras, spots: spotExtras };
    if (Object.keys(listingExtras).length > 0 || Object.keys(spotExtras).length > 0) {
      params.set("extras", encodeURIComponent(JSON.stringify(payload)));
    }
    router.push(`/book/${listing.id}?${params.toString()}`);
  };

  const priceLabel = listing.priceUnit === "time" ? "dag" : "natt";
  const hasListingExtras = (listing.extras || []).length > 0;

  const buttonDisabled =
    checkingAvailability ||
    (availability !== null && availability.availableSpots === 0) ||
    (hasSpotLevelPricing && nights > 0 && selectedSpotIds.length === 0);

  return (
    <div className="lg:sticky lg:top-24 rounded-xl border border-neutral-200 bg-white p-4 sm:p-6 shadow-sm">
      <div className="flex items-baseline justify-between">
        <div>
          <span className="text-2xl font-bold text-neutral-900">
            {getDisplayPriceText(listing)} kr
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

      {nights > 0 && availability && !hasSpotLevelPricing && (
        <div className="mt-4 flex items-center gap-2 rounded-lg bg-neutral-50 px-3 py-2 text-sm">
          <Users className="h-4 w-4 text-neutral-400" />
          <span className={availability.availableSpots === 0 ? "font-medium text-red-600" : "text-neutral-600"}>
            {availability.availableSpots}/{availability.totalSpots} plasser tilgjengelig
          </span>
        </div>
      )}

      {/* Spot picker */}
      {hasSpotLevelPricing && nights > 0 && (
        <div className="mt-4 border-t border-neutral-100 pt-4">
          <p className="text-sm font-medium text-neutral-700 mb-2">Velg plasser</p>
          <div className="space-y-2">
            {spotMarkers.map((spot, i) => {
              if (!spot.id) return null;
              const isSelected = selectedSpotIds.includes(spot.id);
              const price = spot.price ?? listing.price;
              const blocked = isSpotBlocked(spot);
              return (
                <div key={spot.id} className={`rounded-lg border ${blocked ? "border-neutral-200 bg-neutral-50 opacity-60" : isSelected ? "border-primary-600 bg-primary-50" : "border-neutral-200"}`}>
                  <button
                    type="button"
                    onClick={() => !blocked && toggleSpot(spot.id!)}
                    disabled={blocked}
                    className="flex w-full items-center gap-3 px-3 py-2.5 text-left"
                  >
                    <div className={`flex h-8 w-8 items-center justify-center rounded-full ${blocked ? "bg-neutral-100 text-neutral-400" : isSelected ? "bg-primary-600 text-white" : "bg-neutral-100 text-neutral-500"}`}>
                      <MapPin className="h-4 w-4" />
                    </div>
                    <div className="flex-1">
                      <div className="text-sm font-medium text-neutral-900">{spot.label ?? `Plass ${i + 1}`}</div>
                      <div className="text-xs text-neutral-500">
                        {blocked ? "Ikke tilgjengelig for disse datoene" : `${price} kr/natt`}
                      </div>
                    </div>
                    <div className={`flex h-5 w-5 items-center justify-center rounded border-2 ${blocked ? "border-neutral-300" : isSelected ? "border-primary-600 bg-primary-600" : "border-neutral-300"}`}>
                      {isSelected && !blocked && <svg className="h-3 w-3 text-white" viewBox="0 0 12 12"><path d="M10 3L4.5 8.5L2 6" stroke="currentColor" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
                    </div>
                  </button>
                  {isSelected && spot.extras && spot.extras.length > 0 && (
                    <div className="border-t border-primary-200 px-3 py-2 space-y-1.5">
                      {spot.extras.map((extra) => {
                        const qty = spotExtras[spot.id!]?.[extra.id] || 0;
                        return (
                          <div key={extra.id} className="flex items-center justify-between text-sm">
                            <div className="flex items-center gap-1.5">
                              <Sparkles className="h-3 w-3 text-primary-600" />
                              <span className="text-neutral-700">{extra.name}</span>
                              <span className="text-xs text-neutral-400">
                                {extra.price} kr{extra.perNight ? "/natt" : ""}
                              </span>
                            </div>
                            <div className="flex items-center gap-2">
                              <button
                                onClick={() => toggleSpotExtra(spot.id!, extra.id, -1)}
                                disabled={qty === 0}
                                className="flex h-6 w-6 items-center justify-center rounded-full border border-neutral-200 text-neutral-500 disabled:opacity-30"
                              >
                                <Minus className="h-3 w-3" />
                              </button>
                              <span className="w-4 text-center text-sm">{qty}</span>
                              <button
                                onClick={() => toggleSpotExtra(spot.id!, extra.id, 1)}
                                className="flex h-6 w-6 items-center justify-center rounded-full border border-neutral-200 text-neutral-500"
                              >
                                <Plus className="h-3 w-3" />
                              </button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Listing-wide extras */}
      {hasListingExtras && nights > 0 && (
        <div className="mt-4 border-t border-neutral-100 pt-4">
          <p className="text-sm font-medium text-neutral-700 mb-3">Tilleggstjenester</p>
          <div className="space-y-2">
            {(listing.extras || []).map((extra) => {
              const qty = listingExtras[extra.id] || 0;
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
                      onClick={() => toggleListingExtra(extra.id, -1)}
                      disabled={qty === 0}
                      className="flex h-7 w-7 items-center justify-center rounded-full border border-neutral-200 text-neutral-500 disabled:opacity-30 hover:bg-neutral-50"
                    >
                      <Minus className="h-3 w-3" />
                    </button>
                    <span className="w-4 text-center text-sm font-medium">{qty}</span>
                    <button
                      onClick={() => toggleListingExtra(extra.id, 1)}
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
              {hasSpotLevelPricing && selectedSpots.length > 0
                ? `${selectedSpots.length} plass${selectedSpots.length > 1 ? "er" : ""} × ${nights} ${nights === 1 ? "natt" : "netter"}`
                : `${listing.price} kr × ${nights} ${nights === 1 ? priceLabel : priceLabel === "dag" ? "dager" : "netter"}`}
            </span>
            <span>{baseTotal} kr</span>
          </div>
          {(listingExtrasTotal + spotExtrasTotal) > 0 && (
            <div className="flex justify-between text-neutral-600">
              <span>Tilleggstjenester</span>
              <span>{listingExtrasTotal + spotExtrasTotal} kr</span>
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
        disabled={buttonDisabled}
      >
        {checkingAvailability
          ? "Sjekker tilgjengelighet..."
          : availability?.availableSpots === 0
            ? "Fullbooket"
            : hasSpotLevelPricing && nights > 0 && selectedSpotIds.length === 0
              ? "Velg minst én plass"
              : dateRange?.from && dateRange?.to
                ? "Reserver"
                : "Sjekk tilgjengelighet"}
      </Button>
    </div>
  );
}
